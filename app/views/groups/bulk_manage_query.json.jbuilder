# for data table
json.data do
  json.array! @groups do |group|
    json.extract! group, :id, :name, :description, :enabled, :allow_user_change_name
    json.users_count group.users.count
    json.problems_count group.problems.count
  end
end
