require "test_helper"

class GraderConfigurationTest < ActiveSupport::TestCase
  # --- Config access ---

  test "get returns config value" do
    val = GraderConfiguration.get("ui.front.title")
    assert_equal "Grader", val
  end

  test "bracket accessor works like get" do
    assert_equal GraderConfiguration.get("ui.front.title"), GraderConfiguration["ui.front.title"]
  end

  test "get returns nil for non-existent key" do
    assert_nil GraderConfiguration.get("nonexistent.key")
  end

  test "get returns boolean for boolean type" do
    val = GraderConfiguration.get("system.single_user_mode")
    assert_equal false, val
  end

  # --- Mode queries ---

  test "standard_mode? returns true when mode is standard" do
    assert GraderConfiguration.standard_mode?
  end

  test "contest_mode? returns false in standard mode" do
    assert_not GraderConfiguration.contest_mode?
  end

  test "contest_mode? returns true when set" do
    set_grader_config("system.mode", "contest")
    assert GraderConfiguration.contest_mode?
  end

  test "indv_contest_mode? returns true when set" do
    set_grader_config("system.mode", "indv-contest")
    assert GraderConfiguration.indv_contest_mode?
  end

  test "analysis_mode? returns true when set" do
    set_grader_config("system.mode", "analysis")
    assert GraderConfiguration.analysis_mode?
  end

  test "time_limit_mode? returns true for contest and indv-contest" do
    set_grader_config("system.mode", "contest")
    assert GraderConfiguration.time_limit_mode?

    set_grader_config("system.mode", "indv-contest")
    assert GraderConfiguration.time_limit_mode?
  end

  # --- Boolean configs ---

  test "single_user_mode? defaults to false" do
    assert_not GraderConfiguration.single_user_mode?
  end

  test "multicontests? defaults to false" do
    assert_not GraderConfiguration.multicontests?
  end

  test "use_problem_group? defaults to false" do
    assert_not GraderConfiguration.use_problem_group?
  end

  # --- set_exam_mode ---

  test "set_exam_mode updates multiple configs" do
    GraderConfiguration.set_exam_mode(true)
    reset_grader_config_cache
    assert_not GraderConfiguration["right.bypass_agreement"]
    assert_not GraderConfiguration["right.multiple_ip_login"]
  end

  # --- theme_selector_enabled ---

  test "theme_selector_enabled? returns true when configured" do
    assert GraderConfiguration.theme_selector_enabled?
    assert GraderConfiguration["gimmicks.theme_selector_enabled"]
  end

  test "theme_selector_enabled backward compatibility lookup" do
    assert_equal GraderConfiguration["gimmicks.theme_selector_enabled"], GraderConfiguration["system.theme_selector_enabled"]
  end

  # --- 3-state configs (gimmicks, scoreboard, hall of fame) ---

  test "gimmicks 3-state: always_on, outside_contest, and off behave properly across modes" do
    set_grader_config("gimmicks.enable_bonus", "always_on")
    set_grader_config("system.mode", "standard")
    assert GraderConfiguration.enable_bonus?
    set_grader_config("system.mode", "contest")
    assert GraderConfiguration.enable_bonus?

    set_grader_config("gimmicks.enable_bonus", "outside_contest")
    set_grader_config("system.mode", "standard")
    assert GraderConfiguration.enable_bonus?
    set_grader_config("system.mode", "analysis")
    assert GraderConfiguration.enable_bonus?
    set_grader_config("system.mode", "contest")
    assert_not GraderConfiguration.enable_bonus?
    set_grader_config("system.mode", "indv-contest")
    assert_not GraderConfiguration.enable_bonus?

    set_grader_config("gimmicks.enable_bonus", "off")
    set_grader_config("system.mode", "standard")
    assert_not GraderConfiguration.enable_bonus?
  end

  test "scoreboard_enabled?, hall_of_fame_enabled?, and llm_assist_enabled? support 3 states" do
    set_grader_config("system.scoreboard_enabled", "outside_contest")
    set_grader_config("right.user_hall_of_fame", "outside_contest")
    GraderConfiguration.find_or_create_by!(key: "system.llm_assist") do |c|
      c.value_type = "string"
      c.value = "outside_contest"
    end.update!(value_type: "string", value: "outside_contest")
    reset_grader_config_cache

    set_grader_config("system.mode", "standard")
    assert GraderConfiguration.scoreboard_enabled?
    assert GraderConfiguration.hall_of_fame_enabled?
    assert GraderConfiguration.llm_assist_enabled?

    set_grader_config("system.mode", "contest")
    assert_not GraderConfiguration.scoreboard_enabled?
    assert_not GraderConfiguration.hall_of_fame_enabled?
    assert_not GraderConfiguration.llm_assist_enabled?

    set_grader_config("system.scoreboard_enabled", "always_on")
    set_grader_config("right.user_hall_of_fame", "always_on")
    set_grader_config("system.llm_assist", "always_on")
    assert GraderConfiguration.scoreboard_enabled?
    assert GraderConfiguration.hall_of_fame_enabled?
    assert GraderConfiguration.llm_assist_enabled?

    set_grader_config("system.scoreboard_enabled", "off")
    set_grader_config("right.user_hall_of_fame", "off")
    set_grader_config("system.llm_assist", "off")
    set_grader_config("system.mode", "standard")
    assert_not GraderConfiguration.scoreboard_enabled?
    assert_not GraderConfiguration.hall_of_fame_enabled?
    assert_not GraderConfiguration.llm_assist_enabled?
  end
end
