module ApplicationHelper
  # Renders a <time> element that converts UTC timestamps to the user's local timezone via Stimulus.
  # The server-rendered text is a UTC fallback; the JS controller replaces it on connect().
  #
  # Format names:
  #   short-date       → "Feb 14, 2026"
  #   long-date        → "February 14, 2026"
  #   month-day        → "Feb 14"
  #   short-datetime   → "Feb 14, 2026, 9:30 PM"
  #   long-datetime    → "February 14, 2026, 9:30:00 PM"
  #   time-only        → "9:30 PM"
  #   compact-datetime → "Feb 14, 9:30 PM"
  #   month-year       → "Feb 2026"
  #   month-only       → "Feb"
  #
  def local_time(datetime, format_name = "short-date")
    return content_tag(:span, "—", class: "opacity-40") if datetime.nil?

    iso = datetime.respond_to?(:iso8601) ? datetime.iso8601 : datetime.to_time.iso8601
    fallback = format_datetime_fallback(datetime, format_name)

    content_tag(:time,
      fallback,
      datetime: iso,
      data: {
        controller: "local-time",
        "local-time-format-value": format_name
      }
    )
  end

  private

  def format_datetime_fallback(datetime, format_name)
    case format_name
    when "short-date"      then datetime.strftime("%b %d, %Y")
    when "long-date"       then datetime.strftime("%B %d, %Y")
    when "month-day"       then datetime.strftime("%b %d")
    when "short-datetime"  then datetime.strftime("%b %d, %Y, %l:%M %p").squish
    when "long-datetime"   then datetime.strftime("%B %d, %Y, %l:%M:%S %p").squish
    when "time-only"       then datetime.strftime("%l:%M %p").strip
    when "compact-datetime" then datetime.strftime("%b %d, %l:%M %p").squish
    when "month-year"      then datetime.strftime("%b %Y")
    when "month-only"      then datetime.strftime("%b")
    else datetime.strftime("%b %d, %Y")
    end
  rescue
    datetime.to_s
  end
end
