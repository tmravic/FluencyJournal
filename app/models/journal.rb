class Journal < ApplicationRecord
  belongs_to :user
  belongs_to :group
  has_many :entries, dependent: :destroy
  has_many :ai_queries, dependent: :destroy
  has_many :quizzes, dependent: :destroy

  validates :title, presence: true

  scope :ordered, -> { order(created_at: :desc) }
  # scope :personal, -> {  }
  # scope :private, -> {  }
  # scope :public, -> {  }
  # scope :shared (either private or publish, not personal), -> {  }

  # after_create_commit -> { broadcast_prepend_later_to "journals" }
  # after_update_commit -> { broadcast_replace_later_to "journals" }
  # after_destroy_commit -> { broadcast_remove_to "journals" }
  broadcasts_to ->(journals) { [ journals.group, "journals" ] }, inserts_by: :prepend
  # The signed stream name is generated from the array returned by the lambda
  # that is the first argument of the broadcasts_to method: [journals.group, "journals"].

  def full_journal
    self.entries.pluck(:content)
    # ["先日の日曜日に可愛い女の子と会いました。その子の人生についていろいろ教えてくれました。",
    #  "その子が年上のお金持ちの男性と遊んでいる話を聞いて驚きました。",
    #  "東京にいる面白い人との繋がりが多くてうらやましかった。"]
  end
end
