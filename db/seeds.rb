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

user1 = User.find_by(email_address: 'taylor@kpmg.com')
user2 = User.find_by(email_address: 'admin@admin.com')

journals = [
  { title: 'ニキータさん', user_id: user1.id, group: Group.find_by(name: "JapaneseGroup") },
  { title: 'title2', user_id: user1.id, group: Group.find_by(name: "JapaneseGroup") },
  { title: 'title3', user_id: user2.id, group: Group.find_by(name: "EnglishGroup") },
  { title: 'title4', user_id: user2.id, group: Group.find_by(name: "EnglishGroup") }
]
journals.each do |journal_attrs|
  Journal.find_or_create_by(title: journal_attrs[:title], user_id: journal_attrs[:user_id]) do |journal|
    journal.group = journal_attrs[:group]
  end
end

commits = [
  { journal_id: Journal.find_by(title: 'ニキータさん').id, content: "先日の日曜日に可愛い女の子と会いました。その子の人生についていろいろ教えてくれました。" },
  { journal_id: Journal.find_by(title: 'ニキータさん').id, content: "その子が年上のお金持ちの男性と遊んでいる話を聞いて驚きました。" },
  { journal_id: Journal.find_by(title: 'ニキータさん').id, content: "私は彼女の人生にいる他の男性と競争できない気がした。" },
  { journal_id: Journal.find_by(title: 'ニキータさん').id, content: "話し終わった後は空虚な気持ちになった。" },
  { journal_id: Journal.find_by(title: 'title2').id, content: "commit content 2" }
]
commits.each do |commit_attrs|
  Commit.find_or_create_by(journal_id: commit_attrs[:journal_id], content: commit_attrs[:content])
end

# user1.notes.create(content: '312 hours ago', category: 3, next_study_date: DateTime.now - 312.hours)
# user1.notes.create(content: '288 hours ago', category: 2, next_study_date: DateTime.now - 288.hours)
# user1.notes.create(content: '264 hours ago', category: 1, next_study_date: DateTime.now - 264.hours)
# user1.notes.create(content: '240 hours ago', category: 0, next_study_date: DateTime.now - 240.hours)
# user1.notes.create(content: '216 hours ago', category: 3, next_study_date: DateTime.now - 216.hours)
# user1.notes.create(content: '192 hours ago', category: 2, next_study_date: DateTime.now - 192.hours)
# user1.notes.create(content: '168 hours ago', category: 1, next_study_date: DateTime.now - 168.hours)
# user1.notes.create(content: '144 hours ago', category: 0, next_study_date: DateTime.now - 144.hours)
# user1.notes.create(content: '120 hours ago', category: 0, next_study_date: DateTime.now - 120.hours)
# user1.notes.create(content: '96 hours ago', category: 0, next_study_date: DateTime.now - 96.hours)
# user1.notes.create(content: '72 hours ago', category: 0, next_study_date: DateTime.now - 72.hours)
# user1.notes.create(content: '48 hours ago', category: 1, next_study_date: DateTime.now - 48.hours)
user1.notes.create(content: '24 hours ago', category: 2, next_study_date: DateTime.now - 24.hours)
user1.notes.create(content: 'Right now', category: 3, next_study_date: DateTime.now)
user1.notes.create(content: '24 hours later', category: 0, next_study_date: DateTime.now + 24.hours)
# user1.notes.create(content: '48 hours later', category: 1, next_study_date: DateTime.now + 48.hours)
# user1.notes.create(content: '72 hours later', category: 2, next_study_date: DateTime.now + 72.hours)
# user1.notes.create(content: '96 hours later', category: 2, next_study_date: DateTime.now + 96.hours)
# user1.notes.create(content: '120 hours later', category: 0, next_study_date: DateTime.now + 120.hours)
# user1.notes.create(content: '144 hours later', category: 1, next_study_date: DateTime.now + 144.hours)
# user1.notes.create(content: '168 hours later', category: 2, next_study_date: DateTime.now + 168.hours)
# user1.notes.create(content: '192 hours later', category: 3, next_study_date: DateTime.now + 192.hours)
# user1.notes.create(content: '216 hours later', category: 0, next_study_date: DateTime.now + 216.hours)
# user1.notes.create(content: '240 hours later', category: 1, next_study_date: DateTime.now + 240.hours)
# user1.notes.create(content: '264 hours later', category: 2, next_study_date: DateTime.now + 264.hours)
# user1.notes.create(content: '288 hours later', category: 3, next_study_date: DateTime.now + 288.hours)

# user2.notes.create(content: '312 hours ago', category: 3, next_study_date: DateTime.now - 312.hours)
# user2.notes.create(content: '288 hours ago', category: 2, next_study_date: DateTime.now - 288.hours)
# user2.notes.create(content: '264 hours ago', category: 1, next_study_date: DateTime.now - 264.hours)
# user2.notes.create(content: '240 hours ago', category: 0, next_study_date: DateTime.now - 240.hours)
# user2.notes.create(content: '216 hours ago', category: 3, next_study_date: DateTime.now - 216.hours)
# user2.notes.create(content: '192 hours ago', category: 2, next_study_date: DateTime.now - 192.hours)
# user2.notes.create(content: '168 hours ago', category: 1, next_study_date: DateTime.now - 168.hours)
# user2.notes.create(content: '144 hours ago', category: 0, next_study_date: DateTime.now - 144.hours)
# user2.notes.create(content: '120 hours ago', category: 0, next_study_date: DateTime.now - 120.hours)
# user2.notes.create(content: '96 hours ago', category: 0, next_study_date: DateTime.now - 96.hours)
# user2.notes.create(content: '72 hours ago', category: 0, next_study_date: DateTime.now - 72.hours)
# user2.notes.create(content: '48 hours ago', category: 1, next_study_date: DateTime.now - 48.hours)
user2.notes.create(content: '24 hours ago', category: 2, next_study_date: DateTime.now - 24.hours)
user2.notes.create(content: 'Right now', category: 3, next_study_date: DateTime.now)
user2.notes.create(content: '24 hours later', category: 0, next_study_date: DateTime.now + 24.hours)
# user2.notes.create(content: '48 hours later', category: 1, next_study_date: DateTime.now + 48.hours)
# user2.notes.create(content: '72 hours later', category: 2, next_study_date: DateTime.now + 72.hours)
# user2.notes.create(content: '96 hours later', category: 2, next_study_date: DateTime.now + 96.hours)
# user2.notes.create(content: '120 hours later', category: 0, next_study_date: DateTime.now + 120.hours)
# user2.notes.create(content: '144 hours later', category: 1, next_study_date: DateTime.now + 144.hours)
# user2.notes.create(content: '168 hours later', category: 2, next_study_date: DateTime.now + 168.hours)
# user2.notes.create(content: '192 hours later', category: 3, next_study_date: DateTime.now + 192.hours)
# user2.notes.create(content: '216 hours later', category: 0, next_study_date: DateTime.now + 216.hours)
# user2.notes.create(content: '240 hours later', category: 1, next_study_date: DateTime.now + 240.hours)
# user2.notes.create(content: '264 hours later', category: 2, next_study_date: DateTime.now + 264.hours)
# user2.notes.create(content: '288 hours later', category: 3, next_study_date: DateTime.now + 288.hours)
