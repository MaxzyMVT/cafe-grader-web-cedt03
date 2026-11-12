require "test_helper"

class JobTest < ActiveSupport::TestCase
  # --- Enums ---

  test "status enum values" do
    assert jobs(:job_waiting).wait?
    assert jobs(:job_processing).process?
    assert jobs(:job_success).success?
    assert jobs(:job_error).error?
  end

  test "job_type enum values" do
    job = Job.new(job_type: :compile)
    assert job.jt_compile?
  end

  # --- Scopes ---

  test "oldest_waiting returns only waiting jobs" do
    waiting = Job.oldest_waiting
    assert waiting.all?(&:wait?)
    assert_includes waiting, jobs(:job_waiting)
    assert_not_includes waiting, jobs(:job_success)
  end

  test "finished returns success and error jobs" do
    finished = Job.finished
    assert_includes finished, jobs(:job_success)
    assert_includes finished, jobs(:job_error)
    assert_not_includes finished, jobs(:job_waiting)
  end

  # --- Class methods ---

  test "add_compiling_job creates a compile job" do
    sub = submissions(:add1_by_admin)
    ds = datasets(:ds_add)
    assert_difference "Job.count" do
      Job.add_compiling_job(sub, ds, 0)
    end
    job = Job.last
    assert job.jt_compile?
    assert_equal sub.id, job.arg
  end

  test "add_compiling_job raises without dataset" do
    sub = submissions(:add1_by_admin)
    assert_raises(GraderError) do
      Job.add_compiling_job(sub, nil, 0)
    end
  end

  test "has_waiting_job returns true when waiting jobs exist" do
    assert Job.has_waiting_job
  end

  test "clean_old_job removes old finished jobs" do
    jobs(:job_success).update(updated_at: 2.days.ago)
    assert_difference "Job.count", -1 do
      Job.clean_old_job(1.day)
    end
  end

  # --- reclaim_stale_jobs: a grader that died holding a job must not strand it in "process" ---

  def stuck_job(heartbeat:, job_age:, result: nil)
    gp = GraderProcess.create!(worker_id: 99, box_id: GraderProcess.maximum(:box_id).to_i + 1, enabled: true, last_heartbeat: heartbeat)
    job = Job.create!(job_type: :evaluate, arg: submissions(:add1_by_admin).id, status: :process, grader_process: gp, result: result)
    job.update_columns(updated_at: job_age)
    job
  end

  test "reclaim_stale_jobs requeues a job whose grader has stopped heartbeating" do
    job = stuck_job(heartbeat: 1.hour.ago, job_age: 1.hour.ago)
    assert_equal 1, Job.reclaim_stale_jobs
    assert job.reload.wait?
    assert_match(/reclaim 1/, job.result)
  end

  test "reclaim_stale_jobs leaves a job alone while its grader is still alive" do
    job = stuck_job(heartbeat: 1.minute.ago, job_age: 1.hour.ago)
    assert_equal 0, Job.reclaim_stale_jobs
    assert job.reload.process?
  end

  test "reclaim_stale_jobs leaves a recently claimed job alone even if the grader looks dead" do
    job = stuck_job(heartbeat: 1.hour.ago, job_age: 1.minute.ago)
    assert_equal 0, Job.reclaim_stale_jobs
    assert job.reload.process?
  end

  test "reclaim_stale_jobs gives up after MAX_RECLAIMS and marks the submission as a grading error" do
    job = stuck_job(heartbeat: 1.hour.ago, job_age: 1.hour.ago,
                    result: "reclaim #{Job::MAX_RECLAIMS}: grader process died while holding this job")
    assert_equal 1, Job.reclaim_stale_jobs
    assert job.reload.error?
    assert_equal "grader_error", submissions(:add1_by_admin).reload.status
  end

  test "reclaim_stale_jobs does not touch finished or waiting jobs" do
    jobs(:job_waiting).update_columns(updated_at: 1.day.ago)
    jobs(:job_success).update_columns(updated_at: 1.day.ago)
    assert_equal 0, Job.reclaim_stale_jobs
  end
end
