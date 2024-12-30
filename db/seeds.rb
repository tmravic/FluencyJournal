groups = [
  { name: "JapaneseGroup" },
  { name: "EnglishGroup" }
]
groups.each do |group_attrs|
  Group.find_or_create_by(name: group_attrs[:name])
end

users = [
  {
    email_address: 'admin@admin.com',
    password: '123456',
    group: Group.find_by(name: "EnglishGroup"),
    learning_language: 'English',
    original_language: 'Japanese'
  },
  {
    email_address: 'taylor@kpmg.com',
    password: '123456',
    group: Group.find_by(name: "JapaneseGroup"),
    learning_language: 'Japanese',
    original_language: 'English'
  },
]
users.each do |user_attrs|
  User.find_or_create_by(email_address: user_attrs[:email_address]) do |user|
    user.password = user_attrs[:password]
    user.group = user_attrs[:group]
    user.learning_language = user_attrs[:learning_language]
    user.original_language = user_attrs[:original_language]
  end
end

entries = [
  { title: 'title1', user_id: User.find_by(email_address: 'taylor@kpmg.com').id, group: Group.find_by(name: "JapaneseGroup") },
  { title: 'title2', user_id: User.find_by(email_address: 'taylor@kpmg.com').id, group: Group.find_by(name: "JapaneseGroup") },
  { title: 'title3', user_id: User.find_by(email_address: 'admin@admin.com').id, group: Group.find_by(name: "EnglishGroup") },
  { title: 'title4', user_id: User.find_by(email_address: 'admin@admin.com').id, group: Group.find_by(name: "EnglishGroup") }
]
entries.each do |entry_attrs|
  Entry.find_or_create_by(title: entry_attrs[:title], user_id: entry_attrs[:user_id]) do |entry|
    entry.group = entry_attrs[:group]
  end
end

commits = [
  { entry_id: Entry.find_by(title: 'title1').id, content: "commit content 1" },
  { entry_id: Entry.find_by(title: 'title2').id, content: "commit content 2" }
]
commits.each do |commit_attrs|
  Commit.find_or_create_by(entry_id: commit_attrs[:entry_id], content: commit_attrs[:content])
end

notes = [
  {  }
]