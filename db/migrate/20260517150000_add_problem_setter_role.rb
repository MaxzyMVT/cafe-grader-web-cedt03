class AddProblemSetterRole < ActiveRecord::Migration[8.0]
  def up
    Role.find_or_create_by(name: 'problem_setter')
  end

  def down
    Role.find_by(name: 'problem_setter')&.destroy
  end
end
