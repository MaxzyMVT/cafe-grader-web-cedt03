require "test_helper"

class ScheduledTaskTest < ActiveSupport::TestCase
  test "validates action_type inclusion against strict allow-list" do
    task = ScheduledTask.new(action_type: "eval_arbitrary", scheduled_at: 5.minutes.from_now)
    refute task.valid?
    assert task.errors[:action_type].any?
  end

  test "validates target presence when action requires target" do
    task = ScheduledTask.new(action_type: "disable_contest", scheduled_at: 5.minutes.from_now)
    refute task.valid?
    assert task.errors[:target_id].any?
  end

  test "forces target_type from action definition and ignores arbitrary target_type" do
    contest = Contest.create!(name: "sched_test_contest", enabled: true, start: Time.current, stop: 2.hours.from_now)
    task = ScheduledTask.create!(
      action_type: "disable_contest",
      target_type: "User",
      target_id: contest.id,
      scheduled_at: 1.minute.ago
    )
    assert_equal "Contest", task.target_type
    assert task.execute!
    assert task.reload.completed?
    refute contest.reload.enabled?
  end

  test "executes switch system mode task and updates exam config" do
    mode_conf = GraderConfiguration.find_or_create_by!(key: "system.mode") do |c|
      c.value_type = "string"
      c.value = "standard"
    end
    mode_conf.update!(value: "standard")

    task = ScheduledTask.create!(
      action_type: "set_system_mode",
      payload: { "mode" => "contest" },
      scheduled_at: 1.minute.ago
    )

    assert task.execute!
    assert task.reload.completed?
    assert_equal "contest", mode_conf.reload.value
  end

  test "executes enable and disable group user accounts while protecting admins" do
    group = Group.create!(name: "sched_test_group", enabled: true)
    admin_user = users(:admin)
    student = users(:john)
    student.update!(enabled: false)
    group.users << admin_user unless group.users.include?(admin_user)
    group.users << student unless group.users.include?(student)

    enable_task = ScheduledTask.create!(
      action_type: "enable_group_user_accounts",
      target_id: group.id,
      scheduled_at: 1.minute.ago
    )
    assert enable_task.execute!
    assert student.reload.enabled?

    disable_task = ScheduledTask.create!(
      action_type: "disable_group_user_accounts",
      target_id: group.id,
      scheduled_at: 1.minute.ago
    )
    assert disable_task.execute!
    refute student.reload.enabled?
    assert admin_user.reload.enabled?, "Admin accounts must not be disabled by bulk scheduled tasks"
  end

  test "does not execute future task unless forced" do
    ann = Announcement.create!(title: "Future Ann", body: "Body", published: false)
    task = ScheduledTask.create!(
      action_type: "publish_announcement",
      target_id: ann.id,
      scheduled_at: 1.hour.from_now
    )

    refute task.execute!
    assert task.reload.pending?
    refute ann.reload.published?

    assert task.execute!(force: true)
    assert task.reload.completed?
    assert ann.reload.published?
  end

  test "cannot execute cancelled task" do
    ann = Announcement.create!(title: "Cancelled Ann", body: "Body", published: false)
    task = ScheduledTask.create!(
      action_type: "publish_announcement",
      target_id: ann.id,
      scheduled_at: 1.minute.ago
    )
    assert task.cancel!
    assert task.reload.cancelled?
    refute task.execute!
    refute ann.reload.published?
  end

  test "set_announcement_group sets group and resets to public" do
    ann = Announcement.create!(title: "Group Move Test", body: "Hello", published: true, group_id: nil)
    group = Group.create!(name: "sched_ann_grp", enabled: true)

    task_to_group = ScheduledTask.create!(
      action_type: "set_announcement_group",
      target_id: ann.id,
      payload: { "group_id" => group.id },
      scheduled_at: 1.minute.ago,
      created_by: users(:admin)
    )
    assert task_to_group.execute!
    assert_equal group.id, ann.reload.group_id

    task_to_public = ScheduledTask.create!(
      action_type: "set_announcement_group",
      target_id: ann.id,
      payload: { "group_id" => nil },
      scheduled_at: 1.minute.ago,
      created_by: users(:admin)
    )
    assert task_to_public.execute!
    assert_nil ann.reload.group_id
  end

  test "set_problem_group and set_user_group update group memberships" do
    prob = problems(:prob_add)
    user = users(:john)
    g1 = Group.create!(name: "sched_grp_1", enabled: true)
    g2 = Group.create!(name: "sched_grp_2", enabled: true)

    t_prob = ScheduledTask.create!(
      action_type: "set_problem_group",
      target_id: prob.id,
      payload: { "group_id" => g1.id },
      scheduled_at: 1.minute.ago,
      created_by: users(:admin)
    )
    assert t_prob.execute!
    assert_equal [g1.id], GroupProblem.where(problem_id: prob.id).pluck(:group_id)

    t_prob_clear = ScheduledTask.create!(
      action_type: "set_problem_group",
      target_id: prob.id,
      payload: { "group_id" => nil },
      scheduled_at: 1.minute.ago,
      created_by: users(:admin)
    )
    assert t_prob_clear.execute!
    assert_empty GroupProblem.where(problem_id: prob.id)

    t_user = ScheduledTask.create!(
      action_type: "set_user_group",
      target_id: user.id,
      payload: { "group_id" => g2.id },
      scheduled_at: 1.minute.ago,
      created_by: users(:admin)
    )
    assert t_user.execute!
    assert_equal [g2.id], GroupUser.where(user_id: user.id).pluck(:group_id)

    t_user_clear = ScheduledTask.create!(
      action_type: "set_user_group",
      target_id: user.id,
      payload: { "group_id" => nil },
      scheduled_at: 1.minute.ago,
      created_by: users(:admin)
    )
    assert t_user_clear.execute!
    assert_empty GroupUser.where(user_id: user.id)
  end
end
