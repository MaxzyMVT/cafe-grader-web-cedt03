module ScheduledTasksHelper
  STATUS_STYLES = {
    'pending' => { class: 'bg-primary-subtle text-primary border border-primary-subtle', icon: 'schedule', label: 'Pending' },
    'running' => { class: 'bg-info-subtle text-info-emphasis border border-info-subtle', icon: 'sync', label: 'Running' },
    'completed' => { class: 'bg-success-subtle text-success border border-success-subtle', icon: 'check_circle', label: 'Completed' },
    'failed' => { class: 'bg-danger-subtle text-danger border border-danger-subtle', icon: 'error', label: 'Failed' },
    'cancelled' => { class: 'bg-secondary-subtle text-secondary border border-secondary-subtle', icon: 'cancel', label: 'Cancelled' }
  }.freeze

  def scheduled_task_status_badge(status)
    style = STATUS_STYLES[status.to_s] || STATUS_STYLES['pending']
    tag.span(class: "badge rounded-pill d-inline-flex align-items-center gap-1 px-2 py-1 #{style[:class]}") do
      safe_join([mdi(style[:icon], 'md-16'), tag.span(style[:label])])
    end
  end

  def scheduled_task_category_badge(category)
    meta = ScheduledTask::CATEGORIES[category.to_s] || { label: category.to_s.humanize, icon: 'schedule', badge: 'secondary' }
    badge = meta[:badge]
    text_class = badge == 'warning' || badge == 'info' ? "text-#{badge}-emphasis" : "text-#{badge}"
    tag.span(class: "badge rounded-pill bg-#{badge}-subtle #{text_class} border border-#{badge}-subtle d-inline-flex align-items-center gap-1") do
      safe_join([mdi(meta[:icon], 'md-16'), tag.span(meta[:label])])
    end
  end

  def scheduled_task_target_link(task)
    record = task.resolved_target
    return tag.span("#{task.target_type} ##{task.target_id} (deleted)", class: 'text-muted fst-italic') if task.target_type.present? && record.nil?
    return nil unless record

    case record
    when Contest
      link_to record.name, contest_path(record), class: 'fw-semibold text-decoration-none'
    when Group
      link_to record.name, group_path(record), class: 'fw-semibold text-decoration-none'
    when Problem
      link_to "#{record.name} (#{record.full_name})", edit_problem_path(record), class: 'fw-semibold text-decoration-none'
    when Announcement
      link_to(record.title.presence || "Announcement ##{record.id}", edit_announcement_path(record), class: 'fw-semibold text-decoration-none')
    when User
      link_to "#{record.login} (#{record.full_name})", stat_user_admin_path(record), class: 'fw-semibold text-decoration-none'
    when GraderConfiguration
      link_to record.key, grader_configuration_index_path, class: 'font-monospace fw-semibold text-decoration-none'
    end
  end

  def scheduled_task_grouped_action_options(selected = nil)
    grouped = ScheduledTask::CATEGORIES.map do |cat_key, meta|
      items = ScheduledTask::ACTIONS.select { |_, v| v[:category] == cat_key }.map do |action_key, defn|
        [defn[:label], action_key]
      end
      [meta[:label], items]
    end
    grouped_options_for_select(grouped, selected)
  end

  def scheduled_task_actions_metadata_json
    ScheduledTask::ACTIONS.transform_values do |defn|
      {
        category: defn[:category],
        label: defn[:label],
        description: defn[:description],
        target_type: defn[:target_type],
        payload_kind: defn[:payload_kind]&.to_s
      }
    end.to_json
  end

  def scheduled_task_configs_metadata_json(configs)
    configs.each_with_object({}) do |conf, hash|
      hash[conf.id.to_s] = {
        key: conf.key,
        value_type: conf.value_type,
        value: conf.value,
        description: conf.description
      }
    end.to_json
  end
end
