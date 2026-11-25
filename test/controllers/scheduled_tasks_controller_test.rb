require "test_helper"

class ScheduledTasksControllerTest < ActionDispatch::IntegrationTest
  test "unauthenticated user cannot access scheduled tasks" do
    get scheduled_tasks_path
    assert_redirected_to login_main_path
  end

  test "non-admin user cannot access scheduled tasks" do
    sign_in_as("john", "hello")
    get scheduled_tasks_path
    assert_redirected_to list_main_path
  end

  test "admin can view, create, edit, run_now, cancel, and destroy scheduled tasks" do
    sign_in_as("admin", "admin")

    get scheduled_tasks_path
    assert_response :success

    ann = Announcement.create!(title: "Sched Target", body: "Body", published: false)

    assert_difference("ScheduledTask.count", 1) do
      post scheduled_tasks_path, params: {
        scheduled_task: {
          title: "Publish exam announcement",
          action_type: "publish_announcement",
          announcement_id: ann.id,
          scheduled_at: 1.hour.from_now.strftime("%Y-%m-%dT%H:%M")
        }
      }
    end
    assert_redirected_to scheduled_tasks_path

    task = ScheduledTask.last
    assert task.pending?
    assert_equal "Announcement", task.target_type
    assert_equal ann.id, task.target_id

    get edit_scheduled_task_path(task)
    assert_response :success

    patch scheduled_task_path(task), params: {
      scheduled_task: {
        title: "Updated title",
        action_type: "publish_announcement",
        announcement_id: ann.id,
        scheduled_at: 2.hours.from_now.strftime("%Y-%m-%dT%H:%M")
      }
    }
    assert_redirected_to scheduled_tasks_path
    assert_equal "Updated title", task.reload.title

    post run_now_scheduled_task_path(task)
    assert_redirected_to scheduled_tasks_path
    assert task.reload.completed?
    assert ann.reload.published?

    # Create a second task to test cancel + destroy
    task2 = ScheduledTask.create!(
      action_type: "unpublish_announcement",
      target_id: ann.id,
      scheduled_at: 3.hours.from_now
    )
    post cancel_scheduled_task_path(task2)
    assert_redirected_to scheduled_tasks_path
    assert task2.reload.cancelled?

    assert_difference("ScheduledTask.count", -1) do
      delete scheduled_task_path(task2)
    end
    assert_redirected_to scheduled_tasks_path
  end
end
