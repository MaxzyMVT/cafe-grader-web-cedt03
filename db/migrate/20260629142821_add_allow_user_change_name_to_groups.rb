class AddAllowUserChangeNameToGroups < ActiveRecord::Migration[8.0]
  def change
    add_column :groups, :allow_user_change_name, :boolean, default: false
  end
end
