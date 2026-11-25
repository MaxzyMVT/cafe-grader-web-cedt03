require 'yaml'

#
# This class also contains various login of the system.
#
class GraderConfiguration < ApplicationRecord
  include Auditable
  audited

  after_save :reload_cache

  def reload_cache
    GraderConfiguration.read_config
  end

  SYSTEM_MODE_CONF_KEY = 'system.mode'
  TEST_REQUEST_EARLY_TIMEOUT_KEY = 'contest.test_request.early_timeout'
  MULTICONTESTS_KEY = 'system.multicontests'
  CONTEST_TIME_LIMIT_KEY = 'contest.time_limit'
  MULTIPLE_IP_LOGIN_KEY = 'right.multiple_ip_login'
  VIEW_TESTCASE = 'right.view_testcase'
  SINGLE_USER_KEY = 'system.single_user_mode'
  SYSTEM_USE_PROBLEM_GROUP = 'system.use_problem_group'
  SYSTEM_MINIMUM_LAST_LOGIN_TIME = 'system.min_last_login_time'
  SYSTEM_MESSAGE_ENABLED = 'system.message_enabled'
  SYSTEM_SCOREBOARD_ENABLED = 'system.scoreboard_enabled'
  RIGHT_USER_HALL_OF_FAME = 'right.user_hall_of_fame'
  HINT_ENABLE_ALL_HINTS = 'gimmicks.enable_all_hints'
  SYSTEM_ENABLE_PENALTY = 'gimmicks.enable_penalty'
  SYSTEM_ENABLE_BONUS = 'gimmicks.enable_bonus'
  GIMMICKS_ENABLE_FIRST_BLOODS = 'gimmicks.enable_first_bloods'
  GIMMICKS_ENABLE_SUBMISSION_LIMITS = 'gimmicks.enable_submission_limits'
  GIMMICKS_SHOW_USER_POINTS = 'gimmicks.show_user_points'
  THEME_SELECTOR_ENABLED = 'gimmicks.theme_selector_enabled'

  GIMMICK_STATES = %w[always_on outside_contest off].freeze
  THREE_STATE_EXTRA_KEYS = [
    SYSTEM_SCOREBOARD_ENABLED,
    RIGHT_USER_HALL_OF_FAME,
    'system.theme_selector_enabled'
  ].freeze

  before_validation :normalize_gimmick_value
  validates :value, inclusion: { in: GIMMICK_STATES },
                    if: -> { GraderConfiguration.gimmick_key?(key) && value_type.to_s.downcase == 'string' }

  def self.gimmick_key?(key)
    k = key.to_s
    k.start_with?('gimmicks.') || THREE_STATE_EXTRA_KEYS.include?(k)
  end

  def self.normalize_gimmick_state(val)
    case val
    when true, 'true', 'always_on'
      'always_on'
    when 'outside_contest'
      'outside_contest'
    else
      'off'
    end
  end

  def self.gimmick_active?(key)
    case normalize_gimmick_state(get(key))
    when 'always_on'
      true
    when 'outside_contest'
      !time_limit_mode?
    else
      false
    end
  end


  # class_attribute :config_cache
  cattr_accessor :task_grading_info_cache
  cattr_accessor :contest_time_str
  cattr_accessor :contest_time

  # GraderConfiguration.config_cache = nil
  GraderConfiguration.task_grading_info_cache = nil

  def self.get(key)
    if @config_cache.nil?
      self.read_config
    end

    if key == 'system.theme_selector_enabled' && !@config_cache.key?(key)
      return @config_cache['gimmicks.theme_selector_enabled']
    elsif key == 'gimmicks.theme_selector_enabled' && !@config_cache.key?(key)
      return @config_cache['system.theme_selector_enabled']
    end

    return @config_cache[key]
  end

  def self.[](key)
    self.get(key)
  end

  def self.theme_selector_enabled?
    gimmick_active?(THEME_SELECTOR_ENABLED)
  end

  def self.minimum_last_login_time
    time_text = self.get(SYSTEM_MINIMUM_LAST_LOGIN_TIME)
    return Time.new(time_text) if time_text
    return Date.new(1, 1, 1)
  end

  def self.update_min_last_login
    conf = GraderConfiguration.find_or_create_by(key: SYSTEM_MINIMUM_LAST_LOGIN_TIME)
    conf.update(value: Time.zone.now, value_type: 'string')
  end

  def self.site_name
    return GraderConfiguration.get('ui.site_name')
  end

  #
  # View decision
  #
  def self.show_submitbox_to?(user)
    mode = get(SYSTEM_MODE_CONF_KEY)
    return false if mode=='analysis'
    return true
  end

  def self.show_tasks_to?(user)
    # if time_limit_mode?
    #  return false if not user.contest_started?
    # end
    return true
  end

  def self.show_grading_result
    return (get(SYSTEM_MODE_CONF_KEY)=='analysis')
  end

  def  self.show_testcase
    return get(VIEW_TESTCASE)
  end

  def self.allow_test_request(user)
    mode = get(SYSTEM_MODE_CONF_KEY)
    early_timeout = get(TEST_REQUEST_EARLY_TIMEOUT_KEY)
    if mode=='contest'
      return false if (user.site!=nil) and
        ((user.site.started!=true) or
         (early_timeout and (user.site.time_left < 30.minutes)))
    end
    return false if mode=='analysis'
    return true
  end

  def self.task_grading_info
    if GraderConfiguration.task_grading_info_cache==nil
      read_grading_info
    end
    return GraderConfiguration.task_grading_info_cache
  end

  def self.standard_mode?
    return get(SYSTEM_MODE_CONF_KEY) == 'standard'
  end

  def self.contest_mode?
    return get(SYSTEM_MODE_CONF_KEY) == 'contest'
  end

  def self.indv_contest_mode?
    return get(SYSTEM_MODE_CONF_KEY) == 'indv-contest'
  end

  def self.multicontests?
    return get(MULTICONTESTS_KEY) == true
  end

  def self.time_limit_mode?
    mode = get(SYSTEM_MODE_CONF_KEY)
    return ((mode == 'contest') or (mode == 'indv-contest'))
  end

  def self.analysis_mode?
    return get(SYSTEM_MODE_CONF_KEY) == 'analysis'
  end

  def self.use_problem_group?
    return get(SYSTEM_USE_PROBLEM_GROUP)
  end

  def self.single_user_mode?
    return get(SINGLE_USER_KEY)
  end

  def self.message_enabled?
    res = get(SYSTEM_MESSAGE_ENABLED)
    return true if res.nil?
    return res
  end

  def self.enable_all_hints?
    gimmick_active?(HINT_ENABLE_ALL_HINTS)
  end

  def self.enable_penalty?
    gimmick_active?(SYSTEM_ENABLE_PENALTY)
  end

  def self.enable_bonus?
    gimmick_active?(SYSTEM_ENABLE_BONUS)
  end

  def self.show_first_bloods?
    gimmick_active?(GIMMICKS_ENABLE_FIRST_BLOODS)
  end

  def self.show_submission_limits?
    gimmick_active?(GIMMICKS_ENABLE_SUBMISSION_LIMITS)
  end

  def self.show_user_points?
    val = get(GIMMICKS_SHOW_USER_POINTS)
    return true if val.nil?
    gimmick_active?(GIMMICKS_SHOW_USER_POINTS)
  end

  def self.scoreboard_enabled?
    gimmick_active?(SYSTEM_SCOREBOARD_ENABLED)
  end

  def self.hall_of_fame_enabled?
    gimmick_active?(RIGHT_USER_HALL_OF_FAME)
  end

  def self.contest_time_limit
    contest_time_str = GraderConfiguration[CONTEST_TIME_LIMIT_KEY]

    if not defined? GraderConfiguration.contest_time_str
      GraderConfiguration.contest_time_str = nil
    end

    if GraderConfiguration.contest_time_str != contest_time_str
      GraderConfiguration.contest_time_str = contest_time_str
      if tmatch = /(\d+):(\d+)/.match(contest_time_str)
        h = tmatch[1].to_i
        m = tmatch[2].to_i

        GraderConfiguration.contest_time = h.hour + m.minute
      else
        GraderConfiguration.contest_time = nil
      end
    end
    return GraderConfiguration.contest_time
  end

  def self.set_exam_mode(exam = true)
    value = exam ? 'false' : 'true'

    GraderConfiguration.where(key: "right.bypass_agreement").update(value: value)
    GraderConfiguration.where(key: "right.multiple_ip_login").update(value: value)
    # right.user_hall_of_fame uses 3-state (always_on / outside_contest / off) and adapts automatically
    GraderConfiguration.where(key: "right.user_view_submission").update(value: value)
    GraderConfiguration.where(key: "right.view_testcase").update(value: value)

    User.update_all(last_ip: false)
  end

  protected

  def normalize_gimmick_value
    return unless GraderConfiguration.gimmick_key?(key) && value_type.to_s.downcase == 'string'
    case value.to_s.downcase
    when 'true'
      self.value = 'always_on'
    when 'false'
      self.value = 'off'
    end
  end

  def self.convert_type(val, type)
    case type
    when 'string'
      return val

    when 'integer'
      return val.to_i

    when 'boolean'
      return (val=='true')
    end
  end

  def self.read_config
    @config_cache = {}
    # GraderConfiguration.config_cache = {}
    GraderConfiguration.all.each do |conf|
      key = conf.key
      val = conf.value
      # GraderConfiguration.config_cache[key] = GraderConfiguration.convert_type(val, conf.value_type)
      @config_cache[key] = GraderConfiguration.convert_type(val, conf.value_type)
    end
    return @config_cache
    # return GraderConfiguration.config_cache
  end

  # def self.read_one_key(key)
  #  conf = GraderConfiguration.find_by_key(key)
  #  if conf
  #    return GraderConfiguration.convert_type(conf.value,conf.value_type)
  #  else
  #    return nil
  #  end
  # end

  def self.read_grading_info
    f = File.open(TASK_GRADING_INFO_FILENAME)
    GraderConfiguration.task_grading_info_cache = YAML.load(f)
    f.close
  end
end
