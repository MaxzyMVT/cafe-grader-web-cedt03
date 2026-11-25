class ConvertGimmicksToThreeState < ActiveRecord::Migration[7.1]
  DESCRIPTIONS = {
    'gimmicks.enable_all_hints' => "Allow users to view all hints even if they haven't unlocked them with points.",
    'gimmicks.enable_penalty' => 'Show scores with deductions (penalties) on scoreboard and reports.',
    'gimmicks.enable_bonus' => 'Calculate and show bonus points on scoreboard and header.',
    'gimmicks.enable_first_bloods' => 'Enable First Blood bonuses and indicators globally.',
    'gimmicks.enable_submission_limits' => 'Enable submission limits globally.',
    'gimmicks.show_user_points' => 'Show the total user points badge on the top navigation bar.',
    'gimmicks.theme_selector_enabled' => 'Allow users to change their UI theme from the settings page.'
  }.freeze

  def up
    GraderConfiguration.reset_column_information
    GraderConfiguration.where("`key` LIKE ? OR `key` = ?", 'gimmicks.%', 'system.theme_selector_enabled').find_each do |conf|
      new_val = case conf.value.to_s.downcase
                when 'true', 'always_on' then 'always_on'
                when 'outside_contest' then 'outside_contest'
                else 'off'
                end
      attrs = { value_type: 'string', value: new_val }
      attrs[:description] = DESCRIPTIONS[conf.key] if DESCRIPTIONS.key?(conf.key)
      conf.update_columns(attrs)
    end
  end

  def down
    GraderConfiguration.reset_column_information
    GraderConfiguration.where("`key` LIKE ? OR `key` = ?", 'gimmicks.%', 'system.theme_selector_enabled').find_each do |conf|
      old_val = %w[always_on outside_contest true].include?(conf.value.to_s.downcase) ? 'true' : 'false'
      conf.update_columns(value_type: 'boolean', value: old_val)
    end
  end
end
