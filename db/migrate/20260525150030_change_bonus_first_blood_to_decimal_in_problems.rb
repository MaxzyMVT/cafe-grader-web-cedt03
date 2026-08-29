class ChangeBonusFirstBloodToDecimalInProblems < ActiveRecord::Migration[8.0]
  def change
    change_column :problems, :bonus_first_blood, :decimal, precision: 16, scale: 6
  end
end
