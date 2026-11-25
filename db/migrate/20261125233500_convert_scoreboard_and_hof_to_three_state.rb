class ConvertScoreboardAndHofToThreeState < ActiveRecord::Migration[7.1]
  def up
    GraderConfiguration.reset_column_information

    if (sb = GraderConfiguration.find_by(key: 'system.scoreboard_enabled'))
      new_val = case sb.value.to_s.downcase
                when 'true', 'always_on' then 'always_on'
                when 'outside_contest' then 'outside_contest'
                else 'off'
                end
      sb.update_columns(
        value_type: 'string',
        value: new_val,
        description: 'Enable the Real-time Scoreboard (Always on, Outside contest, or Off).'
      )
    end

    if (hof = GraderConfiguration.find_by(key: 'right.user_hall_of_fame'))
      new_val = case hof.value.to_s.downcase
                when 'true' then 'outside_contest'
                when 'always_on', 'outside_contest' then hof.value.to_s.downcase
                else 'off'
                end
      hof.update_columns(
        value_type: 'string',
        value: new_val,
        description: 'Allow users to access the Hall of Fame page (Always on, Outside contest, or Off).'
      )
    end
  end

  def down
    GraderConfiguration.reset_column_information

    GraderConfiguration.where(key: %w[system.scoreboard_enabled right.user_hall_of_fame]).find_each do |conf|
      old_val = %w[always_on outside_contest true].include?(conf.value.to_s.downcase) ? 'true' : 'false'
      conf.update_columns(value_type: 'boolean', value: old_val)
    end
  end
end
