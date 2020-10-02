require "sinatra"
require "sinatra/reloader"  # causes app to reload files with every page load
require "tilt/erubis"
require "yaml"

before do
  @menu_list = File.readlines "data/toc.txt", chomp: true
  @profiles = YAML.load_file("users.yaml")
end

helpers do
  def in_paragraphs(text)
    text.split("\n\n").map.with_index do |para, index|
      "<p id=paragraph#{index}>#{para}</p>"
    end.join
  end

  def highlight_search(text, query)
    text.gsub(/#{query}/i, "<strong>#{query}</strong>")
  end

  def count_interests
    users_count = @profiles.count
    interests_count = @profiles.reduce(0) do |total, (name, user)|
      total + user[:interests].count
    end
  end
end

get "/" do
  @title = "Table of Contents"

  erb :home
end

get "/users" do
  @title = "User Profiles"
  @name = params[:name].to_sym unless params[:name].nil? || params[:name].empty?
  
  erb :users_index, layout: :users_layout
end

get "/chapters/:number" do
  number = params[:number].to_i
  chapter_name = @menu_list[number - 1]

  redirect "/" unless (1..@menu_list.size).cover? number

  @title = "Chapter #{number} - #{chapter_name}"
  @text = File.read "data/chp#{number}.txt"  # @text = File.readlines "data/chp#{number}.txt", "\n\n"

  erb :chapter
end

get "/resources" do
  @title = "Resources"
  @files = extract_files("public").sort_by { |file| File.basename(file) }
  @files.reverse! if params[:sort] == "descending"
  
  erb :resources
end

get "/search" do
  @title = "Search"
  @query = params[:query]
  @results = chapters_matching(@query) unless @query.nil? || @query.empty?

  erb :search
end

not_found do
  redirect "/"
end

def extract_files(path)
  Dir.glob("#{path}/*").each_with_object([]) do |item, files|
    Dir.exist?(item) ? files << extract_files(item) : files << item.sub(/public/, "")
  end.flatten
end

def each_chapter
  @menu_list.each_with_index do |name, index|
    number = index + 1
    contents = File.read("data/chp#{number}.txt")
    yield number, name, contents
  end
end

def chapters_matching(query)
  results = []

  each_chapter do |number, name, contents|
    paragraphs = paragraphs_matching(contents, query)
    results << {number: number, name: name, paragraphs: paragraphs} if contents =~ /#{query}/i
  end

  results
end

def paragraphs_matching(contents, query)
  matches = {}

  contents.split("\n\n").each_with_index do |para, idx|
    matches[idx] = para if para =~ /#{query}/i
  end

  matches
end
