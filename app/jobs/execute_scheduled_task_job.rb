class ExecuteScheduledTaskJob < ApplicationJob
  queue_as :default

  def perform(scheduled_task_id)
    task = ScheduledTask.find_by(id: scheduled_task_id)
    return unless task

    task.execute!
  end
end
