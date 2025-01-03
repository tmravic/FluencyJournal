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

entries = [
  { journal_id: Journal.find_by(title: 'ニキータさん').id, content: "先日の日曜日に可愛い女の子と会いました。その子の人生についていろいろ教えてくれました。" },
  { journal_id: Journal.find_by(title: 'ニキータさん').id, content: "その子が年上のお金持ちの男性と遊んでいる話を聞いて驚きました。" },
  { journal_id: Journal.find_by(title: 'ニキータさん').id, content: "私は彼女の人生にいる他の男性と競争できない気がした。" },
  { journal_id: Journal.find_by(title: 'ニキータさん').id, content: "話し終わった後は空虚な気持ちになった。" },
  { journal_id: Journal.find_by(title: 'お寺').id, content: "お寺に祈りに行って、「好きな女の子が私の彼女になりますように」とお願いしました。" }
]
entries.each do |entry_attrs|
  Entry.find_or_create_by(journal_id: entry_attrs[:journal_id], content: entry_attrs[:content])
end

user1.notes.create(content: '24 hours ago', category: 2, next_study_date: DateTime.now - 24.hours)
user1.notes.create(content: 'Right now', category: 3, next_study_date: DateTime.now)
user1.notes.create(content: '24 hours later', category: 0, next_study_date: DateTime.now + 24.hours)

user2.notes.create(content: '24 hours ago', category: 2, next_study_date: DateTime.now - 24.hours)
user2.notes.create(content: 'Right now', category: 3, next_study_date: DateTime.now)
user2.notes.create(content: '24 hours later', category: 0, next_study_date: DateTime.now + 24.hours)
