// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "channels"
import LocalTime from "local-time"

// Weekday names for a review that was a few days ago. Today, yesterday, and
// tomorrow come from the locale files through the document element.
LocalTime.config.i18n.ja = {
  date: {
    dayNames: ["日曜日", "月曜日", "火曜日", "水曜日", "木曜日", "金曜日", "土曜日"],
    abbrDayNames: ["日", "月", "火", "水", "木", "金", "土"],
    monthNames: ["1月", "2月", "3月", "4月", "5月", "6月", "7月", "8月", "9月", "10月", "11月", "12月"],
    abbrMonthNames: ["1月", "2月", "3月", "4月", "5月", "6月", "7月", "8月", "9月", "10月", "11月", "12月"],
    yesterday: "昨日",
    today: "今日",
    tomorrow: "明日",
    on: "{date}",
    formats: {
      default: "%Y-%m-%d",
      thisYear: "%Y-%m-%d"
    }
  }
}

LocalTime.config.i18n.en.date.formats = {
  default: "%Y-%m-%d",
  thisYear: "%Y-%m-%d"
}

const page = document.documentElement
const labels = LocalTime.config.i18n[page.lang] || LocalTime.config.i18n.en
labels.date.today = page.dataset.localTimeToday
labels.date.yesterday = page.dataset.localTimeYesterday
labels.date.tomorrow = page.dataset.localTimeTomorrow
LocalTime.config.locale = page.lang || "en"
LocalTime.start()
document.addEventListener("turbo:morph", () => {
  LocalTime.run()
})