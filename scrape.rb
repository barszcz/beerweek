require "nokogiri"
require "typhoeus"
require "json"

main_page = Typhoeus.get('http://newyorkcitybrewersguild.com/beer-week/2016-beer-week/')
entries = Nokogiri::HTML(main_page.body).css('.post-entry')

hydra = Typhoeus::Hydra.new(max_concurrency: 5)

data = entries.map do |e|
  d = {}
  url = e.at_css('.block-link').attribute('href').value
  info = e.at_css('.event-info')
  d[:name] = info.at_css('h3').text
  d[:date] = info.css('p')[0].text[6..-1]
  d[:location] = info.css('p')[1].text[10..-1]
  d[:time] = info.css('p')[2].text[6..-1]

  req = Typhoeus::Request.new(url)

  callback = lambda do |res|
    if res.success?
      info = Nokogiri::HTML(res.body)
      content = info.at_css('.entry-content')
      d[:summary] = content.at_css('p').text
      link = content.at_css('a')
      d[:url] = link && link.attribute('href').value
    else
      new_req = Typhoeus::Request.new(url)
      new_req.on_complete(&callback)
      hydra.queue(new_req)
    end
  end

  req.on_complete(&callback)
  hydra.queue(req)

  d
end

until hydra.queued_requests.empty?
  hydra.run
end

File.open('data.json', 'w') { |f| f << JSON.pretty_generate(data) }
