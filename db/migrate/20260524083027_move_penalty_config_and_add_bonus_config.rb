class MovePenaltyConfigAndAddBonusConfig < ActiveRecord::Migration[8.0]
  def up
    # 1. Move system.disable_penalty to point_hint.disable_penalty
    penalty_conf = GraderConfiguration.find_by(key: 'system.disable_penalty')
    if penalty_conf
      penalty_conf.update(key: 'point_hint.disable_penalty')
    else
      # Ensure point_hint.disable_penalty exists
      GraderConfiguration.find_or_create_by(key: 'point_hint.disable_penalty') do |c|
        c.value_type = 'boolean'
        c.value = 'false'
        c.description = 'If true, the scoreboard will show scores without any deductions (penalties).'
      end
    end

    # 2. Add point_hint.disable_bonus
    GraderConfiguration.find_or_create_by(key: 'point_hint.disable_bonus') do |c|
      c.value_type = 'boolean'
      c.value = 'false'
      c.description = 'If true, the scoreboard and header will not calculate or show bonus points.'
    end
  end

  def down
    # Reverse it
    penalty_conf = GraderConfiguration.find_by(key: 'point_hint.disable_penalty')
    penalty_conf.update(key: 'system.disable_penalty') if penalty_conf

    bonus_conf = GraderConfiguration.find_by(key: 'point_hint.disable_bonus')
    bonus_conf.destroy if bonus_conf
  end
end
