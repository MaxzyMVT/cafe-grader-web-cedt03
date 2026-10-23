class MoveThemeSelectorToGimmicks < ActiveRecord::Migration[8.0]
  def up
    theme_conf = GraderConfiguration.find_by(key: 'system.theme_selector_enabled')
    if theme_conf
      theme_conf.update!(key: 'gimmicks.theme_selector_enabled')
    end
  end

  def down
    theme_conf = GraderConfiguration.find_by(key: 'gimmicks.theme_selector_enabled')
    if theme_conf
      theme_conf.update!(key: 'system.theme_selector_enabled')
    end
  end
end
