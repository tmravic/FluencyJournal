users = User.create([
  { email_address: 'admin@admin.com', password: '123456' }
])

entries = Entry.create([
  { title: 'title1', content: 'content', user_id: 1 },
  { title: 'title2', content: 'content2', user_id: 1 },
  { title: 'title3', content: 'content3', user_id: 1 },
])