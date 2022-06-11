#!/usr/bin/env ruby
# Export playlist from iTunes library
require 'itunes_parser'
require 'm3u8'
require 'cgi'
require 'pry'

NEW_ROOT = '/home/nymacro/Music/music/iTunes/iTunes Media/'
OLD_ROOT = 'file:///Users/nymacro/Music/iTunes/iTunes Media/'

def unescape(str)
  # for some reason, the encoding of Apple iTunes playlist PLIST
  # doesn't encode/decode '+', so we need to ensure that we preserve it
  CGI.unescape(str.gsub('+', '%2b'))
end

def trim_prefix_and_unescape(str)
  NEW_ROOT + unescape(str)
               .sub(OLD_ROOT, "")
end

def locate_file(filename)
  if File.exists?(filename)
    filename
  else
    path = Pathname.new(filename)
    album = path.parent
    artist = album.parent
    artists = artist.parent
    
    artist_candidates = artists.entries.select { |x| x.basename.to_s.downcase.unicode_normalize == artist.basename.to_s.downcase.unicode_normalize }.map { |x| artists + x }
    
    album_candidates = []
    artist_candidates.each do |a|
      album_candidates.concat(a.entries.select { |x| x.basename.to_s.downcase.unicode_normalize == album.basename.to_s.downcase.unicode_normalize }.map { |x| a + x })
    end

    file_candidates = []
    album_candidates.each do |a|
      file_candidates.concat(a.entries.select { |x| x.basename.to_s.downcase.unicode_normalize == path.basename.to_s.downcase.unicode_normalize }.map { |x| a + x })
    end

    case file_candidates.size
    when 0
      puts "No candidates found for #{filename}"
      filename
    when 1
      file_candidates[0]
    else
      puts "More than one candidate for #{filename}. Picking first"
      file_candidates[0]
    end
  end
rescue => e
  binding.pry
end

ip = ItunesParser.new(file: "library.xml")

SKIP_PLAYLISTS = [
  "####!####",
  "Music",
  "Music Videos",
  "Rentals",
  "Movies",
  "Home Videos",
  "TV Shows",
  "Podcasts",
  "iTunes U",
  "Audiobooks",
  "Books",
  "PDFs",
  "Audiobooks",
  "Apps",
  "Purchased",
  "Genius",
  "90’s Music",
  "Classical Music",
  "Music Videos",
  "My Top Rated",
  "Playlist",
  "Recently Added",
  "Recently Played",
  "Top 25 Most Played",
  "LaunchBar",
  "Books"
]

# only specific playlists.
playlists = ip.playlists
              .reject { |x| SKIP_PLAYLISTS.include?(x['Name']) }
              .map { |x| [x["Playlist ID"], x["Name"]] }

exported = {}

playlists.each do |playlist|
  id, name = playlist
  tracks = ip.playlist_tracks(id)
  
  exported[name] = tracks.map { |x| trim_prefix_and_unescape(x["Location"]) }
end

exported.each_pair do |name, files|
  puts "Exporting playlist #{name}"
  playlist = M3u8::Playlist.new
  files.each do |file|
    playlist.items << M3u8::PlaylistItem.new(uri: locate_file(file))
  end
  IO.binwrite("playlists/#{name}.m3u", playlist.to_s)
end
