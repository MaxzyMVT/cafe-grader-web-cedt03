class RenameGimmicksDisableToEnable < ActiveRecord::Migration[8.0]
  def up
    # 1. gimmicks.disable_bonus -> gimmicks.enable_bonus
    bonus = GraderConfiguration.find_by(key: 'gimmicks.disable_bonus')
    if bonus
      new_val = (bonus.value == 'true' ? 'false' : 'true')
      bonus.update!(
        key: 'gimmicks.enable_bonus',
        value: new_val,
        description: 'If true, the scoreboard and header will calculate and show bonus points.'
      )
    end

    # 2. gimmicks.disable_penalty -> gimmicks.enable_penalty
    penalty = GraderConfiguration.find_by(key: 'gimmicks.disable_penalty')
    if penalty
      new_val = (penalty.value == 'true' ? 'false' : 'true')
      penalty.update!(
        key: 'gimmicks.enable_penalty',
        value: new_val,
        description: 'If true, the scoreboard will show scores with deductions (penalties).'
      )
    end
  end

  def down
    # 1. gimmicks.enable_bonus -> gimmicks.disable_bonus
    bonus = GraderConfiguration.find_by(key: 'gimmicks.enable_bonus')
    if bonus
      new_val = (bonus.value == 'true' ? 'false' : 'true')
      bonus.update!(
        key: 'gimmicks.disable_bonus',
        value: new_val,
        description: 'If true, the scoreboard and header will not calculate or show bonus points.'
      )
    end

    # 2. gimmicks.enable_penalty -> gimmicks.disable_penalty
    penalty = GraderConfiguration.find_by(key: 'gimmicks.enable_penalty')
    if penalty
      new_val = (penalty.value == 'true' ? 'false' : 'true')
      penalty.update!(
        key: 'gimmicks.disable_penalty',
        value: new_val,
        description: 'If true, the scoreboard will show scores without any deductions (penalties).'
      )
    end
  end
end
