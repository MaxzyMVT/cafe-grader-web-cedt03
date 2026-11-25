class ConvertLlmAssistToThreeState < ActiveRecord::Migration[7.1]
  def up
    GraderConfiguration.reset_column_information

    if (conf = GraderConfiguration.find_by(key: 'system.llm_assist'))
      new_val = case conf.value.to_s.downcase
                when 'true', 'always_on' then 'always_on'
                when 'outside_contest' then 'outside_contest'
                else 'off'
                end
      conf.update_columns(
        value_type: 'string',
        value: new_val,
        description: 'Allow users to request LLM assist on submissions (Always on, Outside contest, or Off).'
      )
    end
  end

  def down
    GraderConfiguration.reset_column_information

    if (conf = GraderConfiguration.find_by(key: 'system.llm_assist'))
      old_val = %w[always_on outside_contest true].include?(conf.value.to_s.downcase) ? 'true' : 'false'
      conf.update_columns(value_type: 'boolean', value: old_val)
    end
  end
end
