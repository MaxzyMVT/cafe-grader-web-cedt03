class AddStatisticIncludeAdminsConfig < ActiveRecord::Migration[8.0]
  def up
    GraderConfiguration.where(key: 'system.statistic_include_admins').first_or_create(value_type: 'boolean', value: 'false', description: 'Include admins in statistic reports')
  end

  def down
    GraderConfiguration.where(key: 'system.statistic_include_admins').destroy_all
  end
end
