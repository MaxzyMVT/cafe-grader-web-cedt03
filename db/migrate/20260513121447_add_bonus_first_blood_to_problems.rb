class AddBonusFirstBloodToProblems < ActiveRecord::Migration[8.0]
  def change
    add_column :problems, :bonus_first_blood, :integer
  end
end
