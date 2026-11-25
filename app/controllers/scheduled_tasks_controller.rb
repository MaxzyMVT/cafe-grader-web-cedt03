class ScheduledTasksController < ApplicationController
  before_action :check_valid_login
  before_action :admin_authorization
  before_action :set_scheduled_task, only: [:edit, :update, :destroy, :cancel, :run_now]
  before_action :load_form_collections, only: [:index, :create, :edit, :update]

  ALLOWED_FILTERS = %w[all pending completed failed cancelled].freeze

  def index
    @filter = ALLOWED_FILTERS.include?(params[:status]) ? params[:status] : 'all'
    @counts = {
      all: ScheduledTask.count,
      pending: ScheduledTask.pending.count,
      running: ScheduledTask.running.count,
      completed: ScheduledTask.completed.count,
      failed: ScheduledTask.failed.count,
      cancelled: ScheduledTask.cancelled.count
    }
    @next_task = ScheduledTask.upcoming.first

    scope = ScheduledTask.includes(:created_by).recent_order
    scope = scope.where(status: @filter) unless @filter == 'all'
    @scheduled_tasks = scope.limit(200)

    @scheduled_task = ScheduledTask.new(
      action_type: 'set_system_mode',
      scheduled_at: 10.minutes.from_now.change(sec: 0),
      payload: { 'mode' => 'contest' }
    )
  end

  def create
    @scheduled_task = ScheduledTask.new(build_task_attributes)
    @scheduled_task.created_by = @current_user

    if @scheduled_task.save
      @scheduled_task.enqueue_execution_job!
      redirect_to scheduled_tasks_path, notice: "Scheduled \"#{@scheduled_task.title.presence || @scheduled_task.summary_description}\" for #{@scheduled_task.scheduled_at.strftime('%Y-%m-%d %H:%M')}."
    else
      @filter = 'all'
      @counts = {
        all: ScheduledTask.count,
        pending: ScheduledTask.pending.count,
        running: ScheduledTask.running.count,
        completed: ScheduledTask.completed.count,
        failed: ScheduledTask.failed.count,
        cancelled: ScheduledTask.cancelled.count
      }
      @next_task = ScheduledTask.upcoming.first
      @scheduled_tasks = ScheduledTask.includes(:created_by).recent_order.limit(200)
      render :index, status: :unprocessable_entity
    end
  end

  def edit
    unless @scheduled_task.pending? || @scheduled_task.failed? || @scheduled_task.cancelled?
      redirect_to scheduled_tasks_path, alert: 'Only pending, failed, or cancelled tasks can be edited.'
    end
  end

  def update
    unless @scheduled_task.pending? || @scheduled_task.failed? || @scheduled_task.cancelled?
      redirect_to scheduled_tasks_path, alert: 'Cannot edit a task that is already running or completed.'
      return
    end

    attrs = build_task_attributes
    # Re-arming a failed/cancelled task sets it back to pending
    attrs[:status] = :pending
    attrs[:error_message] = nil

    if @scheduled_task.update(attrs)
      @scheduled_task.enqueue_execution_job!
      redirect_to scheduled_tasks_path, notice: "Updated scheduled task ##{@scheduled_task.id}."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def cancel
    if @scheduled_task.cancel!
      redirect_to scheduled_tasks_path, notice: "Cancelled scheduled task ##{@scheduled_task.id}."
    else
      redirect_to scheduled_tasks_path, alert: 'Task could not be cancelled (it may have already started or finished).'
    end
  end

  def run_now
    if @scheduled_task.execute!(force: true)
      redirect_to scheduled_tasks_path, notice: "Executed task ##{@scheduled_task.id}: #{@scheduled_task.result_message}"
    else
      @scheduled_task.reload
      msg = @scheduled_task.error_message.presence || 'Task could not be executed in its current state.'
      redirect_to scheduled_tasks_path, alert: "Task ##{@scheduled_task.id} failed: #{msg}"
    end
  end

  def destroy
    if @scheduled_task.running?
      redirect_to scheduled_tasks_path, alert: 'Cannot delete a task while it is running.'
      return
    end

    @scheduled_task.destroy
    redirect_to scheduled_tasks_path, notice: "Deleted scheduled task ##{@scheduled_task.id}."
  end

  private

  def set_scheduled_task
    @scheduled_task = ScheduledTask.find(params[:id])
  end

  def load_form_collections
    @contests = Contest.order(id: :desc)
    @groups = Group.order(:name)
    @problems = Problem.order(:name)
    @announcements = Announcement.default_order
    @users = User.order(:login)
    @configurations = GraderConfiguration.order(:key)
  end

  def scheduled_task_params
    params.require(:scheduled_task).permit(
      :title, :action_type, :scheduled_at,
      :contest_id, :group_id, :problem_id, :announcement_id, :user_id, :configuration_id,
      :system_mode, :config_boolean_value, :config_gimmick_value, :config_text_value,
      :announcement_group_id
    )
  end

  def build_task_attributes
    p = scheduled_task_params
    action_type = p[:action_type].to_s
    defn = ScheduledTask::ACTIONS[action_type] || {}

    target_id = case defn[:target_type]
                when 'Contest' then p[:contest_id]
                when 'Group' then p[:group_id]
                when 'Problem' then p[:problem_id]
                when 'Announcement' then p[:announcement_id]
                when 'User' then p[:user_id]
                when 'GraderConfiguration' then p[:configuration_id]
                else nil
                end

    payload = {}
    case defn[:payload_kind]
    when :system_mode
      payload['mode'] = p[:system_mode].to_s
    when :config_value
      conf = GraderConfiguration.find_by(id: target_id)
      payload['value'] = if conf && GraderConfiguration.gimmick_key?(conf.key) && conf.value_type == 'string'
                           p[:config_gimmick_value].to_s
                         elsif conf&.value_type == 'boolean'
                           p[:config_boolean_value].to_s
                         else
                           p[:config_text_value].to_s
                         end
    when :announcement_group
      payload['group_id'] = p[:announcement_group_id].presence&.to_i
    end

    parsed_time = if p[:scheduled_at].present?
                    Time.zone.parse(p[:scheduled_at].to_s)
                  end

    {
      title: p[:title].to_s.strip.presence,
      action_type: action_type,
      target_id: target_id.presence,
      payload: payload,
      scheduled_at: parsed_time
    }
  end
end
