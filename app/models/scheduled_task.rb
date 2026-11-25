class ScheduledTask < ApplicationRecord
  include Auditable
  audited only: %i[title action_type target_type target_id payload scheduled_at status]

  ALLOWED_TARGET_TYPES = %w[Contest Group Problem Announcement User GraderConfiguration].freeze
  ALLOWED_SYSTEM_MODES = %w[standard contest indv-contest analysis].freeze

  ACTIONS = {
    # --- System ---
    'set_system_mode' => {
      category: 'system',
      label: 'Switch System Mode',
      description: 'Change global operating mode (Normal, Contest, Individual Contest, or Analysis) and apply exam rights.',
      icon: 'tune',
      target_type: nil,
      payload_kind: :system_mode
    },
    'set_configuration' => {
      category: 'system',
      label: 'Set System Configuration',
      description: 'Update any GraderConfiguration parameter (boolean toggle or value).',
      icon: 'settings',
      target_type: 'GraderConfiguration',
      payload_kind: :config_value
    },
    'clear_all_session_locks' => {
      category: 'system',
      label: 'Clear All Session Locks',
      description: 'Reset device session locks (last_ip) for all users.',
      icon: 'lock_open',
      target_type: nil,
      payload_kind: nil
    },

    # --- Contest ---
    'enable_contest' => {
      category: 'contest',
      label: 'Enable Contest',
      description: 'Enable a contest so participants can view and join it.',
      icon: 'play_circle',
      target_type: 'Contest',
      payload_kind: nil
    },
    'disable_contest' => {
      category: 'contest',
      label: 'Disable Contest',
      description: 'Disable a contest to hide it from participants.',
      icon: 'pause_circle',
      target_type: 'Contest',
      payload_kind: nil
    },
    'finalize_contest' => {
      category: 'contest',
      label: 'Finalize Contest',
      description: 'Lock a contest as finalized.',
      icon: 'lock',
      target_type: 'Contest',
      payload_kind: nil
    },
    'unfinalize_contest' => {
      category: 'contest',
      label: 'Unfinalize Contest',
      description: 'Unlock a finalized contest for editing.',
      icon: 'lock_open',
      target_type: 'Contest',
      payload_kind: nil
    },
    'enable_contest_user_accounts' => {
      category: 'contest',
      label: 'Enable User Accounts in Contest',
      description: 'Enable login accounts (users.enabled = true) for all participants in a contest.',
      icon: 'how_to_reg',
      target_type: 'Contest',
      payload_kind: nil
    },
    'disable_contest_user_accounts' => {
      category: 'contest',
      label: 'Disable Non-Admin User Accounts in Contest',
      description: 'Disable login accounts (users.enabled = false) for all non-admin participants in a contest.',
      icon: 'person_off',
      target_type: 'Contest',
      payload_kind: nil
    },
    'enable_contest_memberships' => {
      category: 'contest',
      label: 'Enable Contest Memberships',
      description: 'Enable all contest user participation rows (contests_users.enabled = true).',
      icon: 'group_add',
      target_type: 'Contest',
      payload_kind: nil
    },
    'disable_contest_memberships' => {
      category: 'contest',
      label: 'Disable Contest Memberships',
      description: 'Disable all contest user participation rows (contests_users.enabled = false).',
      icon: 'group_remove',
      target_type: 'Contest',
      payload_kind: nil
    },
    'clear_contest_session_locks' => {
      category: 'contest',
      label: 'Clear Session Locks in Contest',
      description: 'Clear device session locks (last_ip) for all participants in a contest.',
      icon: 'lock_reset',
      target_type: 'Contest',
      payload_kind: nil
    },
    'enable_contest_problems' => {
      category: 'contest',
      label: 'Enable All Problems in Contest',
      description: 'Enable all problem memberships in a contest.',
      icon: 'quiz',
      target_type: 'Contest',
      payload_kind: nil
    },
    'disable_contest_problems' => {
      category: 'contest',
      label: 'Disable All Problems in Contest',
      description: 'Disable all problem memberships in a contest.',
      icon: 'visibility_off',
      target_type: 'Contest',
      payload_kind: nil
    },

    # --- Group ---
    'enable_group' => {
      category: 'group',
      label: 'Enable Group',
      description: 'Enable a group.',
      icon: 'groups',
      target_type: 'Group',
      payload_kind: nil
    },
    'disable_group' => {
      category: 'group',
      label: 'Disable Group',
      description: 'Disable/archive a group.',
      icon: 'group_off',
      target_type: 'Group',
      payload_kind: nil
    },
    'enable_group_user_accounts' => {
      category: 'group',
      label: 'Enable All User Accounts in Group',
      description: 'Enable login accounts (users.enabled = true) for all members of a group.',
      icon: 'how_to_reg',
      target_type: 'Group',
      payload_kind: nil
    },
    'disable_group_user_accounts' => {
      category: 'group',
      label: 'Disable Non-Admin User Accounts in Group',
      description: 'Disable login accounts (users.enabled = false) for all non-admin members of a group.',
      icon: 'person_off',
      target_type: 'Group',
      payload_kind: nil
    },
    'clear_group_session_locks' => {
      category: 'group',
      label: 'Clear Session Locks in Group',
      description: 'Clear device session locks (last_ip) for all members of a group.',
      icon: 'lock_reset',
      target_type: 'Group',
      payload_kind: nil
    },
    'enable_group_problems' => {
      category: 'group',
      label: 'Enable All Problems in Group',
      description: 'Enable all problems belonging to a group (groups_problems.enabled & problems.available).',
      icon: 'check_circle',
      target_type: 'Group',
      payload_kind: nil
    },
    'disable_group_problems' => {
      category: 'group',
      label: 'Disable All Problems in Group',
      description: 'Set problems.available = false for all problems belonging to a group.',
      icon: 'unpublished',
      target_type: 'Group',
      payload_kind: nil
    },

    # --- Announcement ---
    'publish_announcement' => {
      category: 'announcement',
      label: 'Publish Announcement',
      description: 'Set announcement published = true.',
      icon: 'campaign',
      target_type: 'Announcement',
      payload_kind: nil
    },
    'unpublish_announcement' => {
      category: 'announcement',
      label: 'Unpublish Announcement',
      description: 'Set announcement published = false.',
      icon: 'visibility_off',
      target_type: 'Announcement',
      payload_kind: nil
    },
    'set_announcement_frontpage' => {
      category: 'announcement',
      label: 'Show Announcement on Front Page',
      description: 'Set announcement frontpage = true.',
      icon: 'home',
      target_type: 'Announcement',
      payload_kind: nil
    },
    'unset_announcement_frontpage' => {
      category: 'announcement',
      label: 'Hide Announcement from Front Page',
      description: 'Set announcement frontpage = false.',
      icon: 'hide_source',
      target_type: 'Announcement',
      payload_kind: nil
    },
    'set_announcement_contest_only' => {
      category: 'announcement',
      label: 'Mark Announcement Contest-Only',
      description: 'Set announcement contest_only = true.',
      icon: 'emoji_events',
      target_type: 'Announcement',
      payload_kind: nil
    },
    'unset_announcement_contest_only' => {
      category: 'announcement',
      label: 'Remove Contest-Only from Announcement',
      description: 'Set announcement contest_only = false.',
      icon: 'public',
      target_type: 'Announcement',
      payload_kind: nil
    },

    # --- Problem ---
    'enable_problem' => {
      category: 'problem',
      label: 'Make Problem Available',
      description: 'Set problem available = true.',
      icon: 'visibility',
      target_type: 'Problem',
      payload_kind: nil
    },
    'disable_problem' => {
      category: 'problem',
      label: 'Make Problem Unavailable',
      description: 'Set problem available = false.',
      icon: 'visibility_off',
      target_type: 'Problem',
      payload_kind: nil
    },
    'enable_all_problems' => {
      category: 'problem',
      label: 'Turn All Problems On',
      description: 'Set available = true on all problems.',
      icon: 'done_all',
      target_type: nil,
      payload_kind: nil
    },
    'disable_all_problems' => {
      category: 'problem',
      label: 'Turn All Problems Off',
      description: 'Set available = false on all problems.',
      icon: 'remove_done',
      target_type: nil,
      payload_kind: nil
    },
    'enable_problem_view_testcase' => {
      category: 'problem',
      label: 'Enable View Testcase on Problem',
      description: 'Set view_testcase = true for a problem.',
      icon: 'fact_check',
      target_type: 'Problem',
      payload_kind: nil
    },
    'disable_problem_view_testcase' => {
      category: 'problem',
      label: 'Disable View Testcase on Problem',
      description: 'Set view_testcase = false for a problem.',
      icon: 'block',
      target_type: 'Problem',
      payload_kind: nil
    },

    # --- User ---
    'enable_user' => {
      category: 'user',
      label: 'Enable User Account',
      description: 'Enable a specific user account.',
      icon: 'person_check',
      target_type: 'User',
      payload_kind: nil
    },
    'disable_user' => {
      category: 'user',
      label: 'Disable User Account',
      description: 'Disable a specific non-admin user account.',
      icon: 'person_off',
      target_type: 'User',
      payload_kind: nil
    },
    'clear_user_session_lock' => {
      category: 'user',
      label: 'Clear User Session Lock',
      description: 'Clear device session lock (last_ip) for a specific user.',
      icon: 'lock_reset',
      target_type: 'User',
      payload_kind: nil
    }
  }.freeze

  CATEGORIES = {
    'system' => { label: 'System & Config', icon: 'settings', badge: 'primary' },
    'contest' => { label: 'Contests', icon: 'emoji_events', badge: 'warning' },
    'group' => { label: 'Groups', icon: 'groups', badge: 'info' },
    'announcement' => { label: 'Announcements', icon: 'campaign', badge: 'success' },
    'problem' => { label: 'Problems', icon: 'quiz', badge: 'secondary' },
    'user' => { label: 'Users', icon: 'person', badge: 'danger' }
  }.freeze

  belongs_to :created_by, class_name: 'User', optional: true

  enum :status, { pending: 0, running: 1, completed: 2, failed: 3, cancelled: 4 }

  scope :upcoming, -> { pending.order(scheduled_at: :asc) }
  scope :due, -> { pending.where('scheduled_at <= ?', Time.current) }
  scope :recent_order, -> { order(Arel.sql('CASE WHEN status = 0 THEN 0 WHEN status = 1 THEN 1 ELSE 2 END ASC'), scheduled_at: :desc) }

  before_validation :normalize_target_and_payload

  validates :action_type, presence: true, inclusion: { in: ACTIONS.keys }
  validates :scheduled_at, presence: true
  validate :validate_target_presence
  validate :validate_payload

  def self.enqueue_due!
    due.find_each do |task|
      ExecuteScheduledTaskJob.perform_later(task.id)
    end
  end

  def action_definition
    ACTIONS[action_type] || {}
  end

  def action_label
    action_definition[:label] || action_type.to_s.humanize
  end

  def action_category
    action_definition[:category] || 'system'
  end

  def action_icon
    action_definition[:icon] || 'schedule'
  end

  def resolved_target
    return nil unless target_type.present? && target_id.present?
    return nil unless ALLOWED_TARGET_TYPES.include?(target_type)

    target_type.constantize.find_by(id: target_id)
  end

  def target_display_name
    record = resolved_target
    return nil unless record

    case record
    when Contest then record.name
    when Group then "#{record.name} (#{record.users.count} users)"
    when Problem then "#{record.name} — #{record.full_name}"
    when Announcement then record.title.presence || "Announcement ##{record.id}"
    when User then "#{record.login} (#{record.full_name})"
    when GraderConfiguration then record.key
    else "##{record.id}"
    end
  end

  def summary_description
    parts = [action_label]
    if target_type.present?
      target_name = target_display_name || "#{target_type} ##{target_id} (deleted)"
      parts << target_name
    end
    case action_definition[:payload_kind]
    when :system_mode
      mode = payload_hash['mode']
      parts << "-> #{mode}" if mode.present?
    when :config_value
      val = payload_hash['value']
      parts << "= #{val}" unless val.nil?
    end
    parts.join(': ')
  end

  def payload_hash
    payload.is_a?(Hash) ? payload : {}
  end

  def enqueue_execution_job!
    return unless pending?

    ExecuteScheduledTaskJob.set(wait_until: scheduled_at).perform_later(id)
  end

  def cancel!
    with_lock do
      return false unless pending?

      update!(status: :cancelled)
    end
    true
  end

  def execute!(force: false)
    should_run = false
    with_lock do
      reload
      if force
        return false unless pending? || failed?
      else
        return false unless pending?
        return false if scheduled_at > Time.current + 5.seconds
      end
      update!(status: :running, error_message: nil)
      should_run = true
    end
    return false unless should_run

    prev_user = Current.user
    prev_actor_note = Current.actor_note
    prev_ip = Current.ip
    begin
      Current.user = created_by
      Current.actor_note = "ScheduledTask ##{id}: #{title.presence || summary_description}"
      Current.ip = nil

      summary = perform_action!
      update!(
        status: :completed,
        executed_at: Time.current,
        result_message: summary,
        error_message: nil
      )
      true
    rescue => e
      Rails.logger.error("[ScheduledTask ##{id}] Execution failed: #{e.class}: #{e.message}")
      update!(
        status: :failed,
        executed_at: Time.current,
        error_message: "#{e.class}: #{e.message}".truncate(1000)
      )
      false
    ensure
      Current.user = prev_user
      Current.actor_note = prev_actor_note
      Current.ip = prev_ip
    end
  end

  private

  def normalize_target_and_payload
    defn = ACTIONS[action_type]
    return unless defn

    expected_type = defn[:target_type]
    if expected_type.present?
      self.target_type = expected_type
      self.target_id = target_id.presence&.to_i
    else
      self.target_type = nil
      self.target_id = nil
    end

    raw_payload = payload.is_a?(Hash) ? payload.stringify_keys : {}
    case defn[:payload_kind]
    when :system_mode
      self.payload = { 'mode' => raw_payload['mode'].to_s.strip }
    when :config_value
      self.payload = { 'value' => raw_payload['value'].to_s }
    else
      self.payload = {}
    end
  end

  def validate_target_presence
    defn = ACTIONS[action_type]
    return unless defn && defn[:target_type].present?

    if target_id.blank?
      errors.add(:target_id, "must be selected for #{defn[:label]}")
      return
    end

    unless resolved_target
      errors.add(:target_id, "#{defn[:target_type]} ##{target_id} was not found")
    end
  end

  def validate_payload
    defn = ACTIONS[action_type]
    return unless defn

    case defn[:payload_kind]
    when :system_mode
      mode = payload_hash['mode']
      unless ALLOWED_SYSTEM_MODES.include?(mode)
        errors.add(:payload, "mode must be one of: #{ALLOWED_SYSTEM_MODES.join(', ')}")
      end
    when :config_value
      conf = resolved_target
      val = payload_hash['value']
      if val.blank?
        errors.add(:payload, 'configuration value cannot be blank')
      elsif conf.is_a?(GraderConfiguration) && conf.value_type == 'boolean' && !%w[true false].include?(val)
        errors.add(:payload, 'boolean configuration value must be true or false')
      elsif conf.is_a?(GraderConfiguration) && conf.value_type == 'integer' && !val.match?(/\A-?\d+\z/)
        errors.add(:payload, 'integer configuration value must be a valid integer')
      end
    end
  end

  def perform_action!
    case action_type
    when 'set_system_mode'
      execute_set_system_mode
    when 'set_configuration'
      execute_set_configuration
    when 'clear_all_session_locks'
      count = User.where.not(last_ip: nil).count
      User.clear_last_login
      AuditLog.record!(
        auditable: self,
        action: 'clear_all_session_locks',
        object_changes: { 'cleared_users' => [nil, count] }
      )
      "Cleared device session locks for all users (#{count} active locks cleared)."
    when 'enable_contest'
      contest = require_target!(Contest)
      contest.update!(enabled: true)
      "Enabled contest \"#{contest.name}\"."
    when 'disable_contest'
      contest = require_target!(Contest)
      contest.update!(enabled: false)
      "Disabled contest \"#{contest.name}\"."
    when 'finalize_contest'
      contest = require_target!(Contest)
      contest.update!(finalized: true)
      "Finalized contest \"#{contest.name}\"."
    when 'unfinalize_contest'
      contest = require_target!(Contest)
      contest.update!(finalized: false)
      "Unfinalized contest \"#{contest.name}\"."
    when 'enable_contest_user_accounts'
      contest = require_target!(Contest)
      count = contest.users.update_all(enabled: true)
      AuditLog.record!(auditable: contest, action: 'scheduled_enable_user_accounts', object_changes: { 'affected_count' => [nil, count] })
      "Enabled #{count} user account(s) in contest \"#{contest.name}\"."
    when 'disable_contest_user_accounts'
      contest = require_target!(Contest)
      admin_ids = User.joins(:roles).where(roles: { name: 'admin' }).pluck(:id)
      count = contest.users.where.not(id: admin_ids).update_all(enabled: false)
      AuditLog.record!(auditable: contest, action: 'scheduled_disable_user_accounts', object_changes: { 'affected_count' => [nil, count] })
      "Disabled #{count} non-admin user account(s) in contest \"#{contest.name}\"."
    when 'enable_contest_memberships'
      contest = require_target!(Contest)
      count = ContestUser.where(contest: contest).update_all(enabled: true)
      AuditLog.record!(auditable: contest, action: 'bulk_enable_users', object_changes: { 'affected_count' => [nil, count] })
      "Enabled #{count} contest membership(s) in \"#{contest.name}\"."
    when 'disable_contest_memberships'
      contest = require_target!(Contest)
      count = ContestUser.where(contest: contest).update_all(enabled: false)
      AuditLog.record!(auditable: contest, action: 'bulk_disable_users', object_changes: { 'affected_count' => [nil, count] })
      "Disabled #{count} contest membership(s) in \"#{contest.name}\"."
    when 'clear_contest_session_locks'
      contest = require_target!(Contest)
      count = contest.users.update_all(last_ip: nil)
      AuditLog.record!(auditable: contest, action: 'bulk_clear_ip', object_changes: { 'affected_count' => [nil, count] })
      "Cleared session locks for #{count} user(s) in contest \"#{contest.name}\"."
    when 'enable_contest_problems'
      contest = require_target!(Contest)
      count = ContestProblem.where(contest: contest).update_all(enabled: true)
      AuditLog.record!(auditable: contest, action: 'bulk_enable_problems', object_changes: { 'affected_count' => [nil, count] })
      "Enabled #{count} problem(s) in contest \"#{contest.name}\"."
    when 'disable_contest_problems'
      contest = require_target!(Contest)
      count = ContestProblem.where(contest: contest).update_all(enabled: false)
      AuditLog.record!(auditable: contest, action: 'bulk_disable_problems', object_changes: { 'affected_count' => [nil, count] })
      "Disabled #{count} problem(s) in contest \"#{contest.name}\"."
    when 'enable_group'
      group = require_target!(Group)
      group.update!(enabled: true)
      AuditLog.record!(auditable: group, action: 'scheduled_enable', object_changes: { 'enabled' => [false, true] })
      "Enabled group \"#{group.name}\"."
    when 'disable_group'
      group = require_target!(Group)
      group.update!(enabled: false)
      AuditLog.record!(auditable: group, action: 'scheduled_disable', object_changes: { 'enabled' => [true, false] })
      "Disabled group \"#{group.name}\"."
    when 'enable_group_user_accounts'
      group = require_target!(Group)
      count = group.users.update_all(enabled: true)
      AuditLog.record!(auditable: group, action: 'scheduled_enable_user_accounts', object_changes: { 'affected_count' => [nil, count] })
      "Enabled #{count} user account(s) in group \"#{group.name}\"."
    when 'disable_group_user_accounts'
      group = require_target!(Group)
      admin_ids = User.joins(:roles).where(roles: { name: 'admin' }).pluck(:id)
      count = group.users.where.not(id: admin_ids).update_all(enabled: false)
      AuditLog.record!(auditable: group, action: 'scheduled_disable_user_accounts', object_changes: { 'affected_count' => [nil, count] })
      "Disabled #{count} non-admin user account(s) in group \"#{group.name}\"."
    when 'clear_group_session_locks'
      group = require_target!(Group)
      count = group.users.update_all(last_ip: nil)
      AuditLog.record!(auditable: group, action: 'scheduled_clear_ip', object_changes: { 'affected_count' => [nil, count] })
      "Cleared session locks for #{count} user(s) in group \"#{group.name}\"."
    when 'enable_group_problems'
      group = require_target!(Group)
      gp_count = GroupProblem.where(group: group).update_all(enabled: true)
      p_count = group.problems.update_all(available: true)
      AuditLog.record!(auditable: group, action: 'scheduled_enable_problems', object_changes: { 'group_problems' => [nil, gp_count], 'problems' => [nil, p_count] })
      "Enabled #{p_count} problem(s) in group \"#{group.name}\"."
    when 'disable_group_problems'
      group = require_target!(Group)
      p_count = group.problems.update_all(available: false)
      AuditLog.record!(auditable: group, action: 'scheduled_disable_problems', object_changes: { 'problems' => [nil, p_count] })
      "Set #{p_count} problem(s) unavailable in group \"#{group.name}\"."
    when 'publish_announcement'
      ann = require_target!(Announcement)
      ann.update!(published: true)
      AuditLog.record!(auditable: ann, action: 'scheduled_publish', object_changes: { 'published' => [false, true] })
      "Published announcement \"#{ann.title}\"."
    when 'unpublish_announcement'
      ann = require_target!(Announcement)
      ann.update!(published: false)
      AuditLog.record!(auditable: ann, action: 'scheduled_unpublish', object_changes: { 'published' => [true, false] })
      "Unpublished announcement \"#{ann.title}\"."
    when 'set_announcement_frontpage'
      ann = require_target!(Announcement)
      ann.update!(frontpage: true)
      AuditLog.record!(auditable: ann, action: 'scheduled_frontpage', object_changes: { 'frontpage' => [false, true] })
      "Shown announcement \"#{ann.title}\" on front page."
    when 'unset_announcement_frontpage'
      ann = require_target!(Announcement)
      ann.update!(frontpage: false)
      AuditLog.record!(auditable: ann, action: 'scheduled_frontpage', object_changes: { 'frontpage' => [true, false] })
      "Hidden announcement \"#{ann.title}\" from front page."
    when 'set_announcement_contest_only'
      ann = require_target!(Announcement)
      ann.update!(contest_only: true)
      AuditLog.record!(auditable: ann, action: 'scheduled_contest_only', object_changes: { 'contest_only' => [false, true] })
      "Marked announcement \"#{ann.title}\" as contest-only."
    when 'unset_announcement_contest_only'
      ann = require_target!(Announcement)
      ann.update!(contest_only: false)
      AuditLog.record!(auditable: ann, action: 'scheduled_contest_only', object_changes: { 'contest_only' => [true, false] })
      "Removed contest-only restriction from announcement \"#{ann.title}\"."
    when 'enable_problem'
      prob = require_target!(Problem)
      prob.update!(available: true)
      "Made problem \"#{prob.name}\" available."
    when 'disable_problem'
      prob = require_target!(Problem)
      prob.update!(available: false)
      "Made problem \"#{prob.name}\" unavailable."
    when 'enable_all_problems'
      count = Problem.update_all(available: true)
      AuditLog.record!(auditable: self, action: 'enable_all_problems', object_changes: { 'affected_count' => [nil, count] })
      "Turned on all #{count} problem(s)."
    when 'disable_all_problems'
      count = Problem.update_all(available: false)
      AuditLog.record!(auditable: self, action: 'disable_all_problems', object_changes: { 'affected_count' => [nil, count] })
      "Turned off all #{count} problem(s)."
    when 'enable_problem_view_testcase'
      prob = require_target!(Problem)
      prob.update!(view_testcase: true)
      "Enabled view_testcase on problem \"#{prob.name}\"."
    when 'disable_problem_view_testcase'
      prob = require_target!(Problem)
      prob.update!(view_testcase: false)
      "Disabled view_testcase on problem \"#{prob.name}\"."
    when 'enable_user'
      user = require_target!(User)
      user.update!(enabled: true)
      "Enabled user \"#{user.login}\"."
    when 'disable_user'
      user = require_target!(User)
      raise "Cannot disable admin user \"#{user.login}\" via scheduled task" if user.admin?

      user.update!(enabled: false)
      "Disabled user \"#{user.login}\"."
    when 'clear_user_session_lock'
      user = require_target!(User)
      user.update!(last_ip: nil)
      "Cleared session lock for user \"#{user.login}\"."
    else
      raise "Unsupported action_type: #{action_type}"
    end
  end

  def require_target!(klass)
    record = klass.find_by(id: target_id)
    raise ActiveRecord::RecordNotFound, "#{klass.name} ##{target_id} not found" unless record

    record
  end

  def execute_set_system_mode
    new_mode = payload_hash['mode']
    raise "Invalid system mode: #{new_mode}" unless ALLOWED_SYSTEM_MODES.include?(new_mode)

    mode_row = GraderConfiguration.find_by!(key: GraderConfiguration::SYSTEM_MODE_CONF_KEY)
    old_mode = mode_row.value

    AuditLog.paused do
      mode_row.update!(value: new_mode)
      if %w[contest indv-contest].include?(new_mode)
        GraderConfiguration.set_exam_mode(true)
      else
        GraderConfiguration.set_exam_mode(false)
      end
    end
    GraderConfiguration.read_config

    AuditLog.record!(
      auditable: mode_row,
      action: 'mode_change',
      object_changes: { 'system.mode' => [old_mode, new_mode] }
    )
    "Switched system mode from #{old_mode} to #{new_mode}."
  end

  def execute_set_configuration
    conf = require_target!(GraderConfiguration)
    new_val = payload_hash['value'].to_s
    old_val = conf.value
    conf.update!(value: new_val)
    if conf.key == GraderConfiguration::SINGLE_USER_KEY && new_val == 'true'
      GraderConfiguration.update_min_last_login
    end
    GraderConfiguration.read_config
    "Updated #{conf.key}: #{old_val} -> #{new_val}."
  end
end
