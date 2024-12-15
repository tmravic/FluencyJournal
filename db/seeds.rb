groups = Group.create([
  { name: "KPMG" },
  { name: "PwC" }
])

users = User.create([
  {
    email_address: 'admin@admin.com',
    password: '123456',
    group: Group.find_by(name: "PwC")
  },
  {
    email_address: 'eavesdropper@pwc.com',
    password: '123456',
    group: Group.find_by(name: "PwC")
  },
  { email_address: 'manager@kpmg.com',
    password: '123456',
    group: Group.find_by(name: "KPMG")
  },
  {
    email_address: 'accountant@kpmg.com',
    password: '123456',
    group: Group.find_by(name: "KPMG")
  }
])

entries = Entry.create([
  { title: 'title1', content: 'content', user_id: 3, group: Group.find_by(name: "KPMG") },
  { title: 'title2', content: 'content2', user_id: 3, group: Group.find_by(name: "KPMG") },
  { title: 'title3', content: 'content3', user_id: 3, group: Group.find_by(name: "KPMG") },
  { title: 'title4', content: 'content4', user_id: 4, group: Group.find_by(name: "PwC") }
])

