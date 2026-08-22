module NativeJapaneseGuidance
  def japanese_diary_guidance(user)
    return "" unless japanese_learner?(user)

    <<~TEXT

      Japanese output style:
      Write corrected_text the way a native speaker would actually write a personal journal, not the way a textbook or a translator would. Prefer natural diary Japanese over a word-for-word translation of the English original.

      Match the student's register. If they used casual forms (た / だ / んだ / ちゃう), keep that. If they used です/ます, keep that. Do not upgrade casual diary writing into polite textbook Japanese unless they asked for it.

      Prefer natural particle choice and Japanese word order. Drop subjects and other obvious context when a native would omit them. Do not add 私は, です/ます, or a sentence-ending period just to look complete. Do not rewrite a grammatical, natural entry just to sound fancier or more complete.

      Target style (copy the register, not the sentences):
      Casual: 今日は仕事終わりに友達と居酒屋行った。刺身が美味しくて、つい飲みすぎちゃった。
      Casual: 電車で席ゆずらなかったおじさんにちょっとイラッとした。まあ疲れてたんだろうけど。
      Polite: 今日は仕事の後、友達と居酒屋に行きました。刺身が美味しくて、つい飲みすぎてしまいました。
    TEXT
  end

  def native_japanese_phrasing(user)
    return "" unless japanese_learner?(user)

    <<~TEXT

      When writing Japanese, prefer how a native would actually say or write it in that situation, not textbook Japanese or a direct translation from English. Match the politeness and casualness of the student's text. Drop pronouns and other obvious context when a native would.
    TEXT
  end

  def japanese_learner?(user)
    user.learning_language == "Japanese"
  end
end
