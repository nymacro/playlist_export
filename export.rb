#!/usr/bin/env ruby
# Export m3u playlists from iTunes library
# Copyright (C) 2022 Aaron Marks. All Rights Reserved.
require 'itunes_parser'
require 'm3u8'
require 'cgi'
require 'pry'

opts = {
  new_root: '/home/nymacro/Music/music/iTunes/iTunes Media/',
  old_root: 'file:///Users/nymacro/Music/iTunes/iTunes Media/',
  skip_playlists: [ "####!####",
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
                    "Books" ],
}

class Exporter
  attr_accessor :ip, :library_xml, :opts

  def initialize(library_xml, opts = {})
    @library_xml = library_xml
    @ip = ItunesParser.new(file: library_xml)
    @opts = opts[:options]
  end

  def run
    # only specific playlists.
    playlists = ip.playlists
                  .reject { |x| opts[:skip_playlists].include?(x['Name']) }
                  .map { |x| [x["Playlist ID"], x["Name"]] }

    exported = {}

    playlists.each do |playlist|
      id, name = playlist
      tracks = ip.playlist_tracks(id)

      exported[name] = tracks.map { |x| trim_prefix_and_unescape(x["Location"], opts) }
    end

    exported.each_pair do |name, files|
      puts "Exporting playlist #{name}"
      playlist = M3u8::Playlist.new
      files.each do |file|
        playlist.items << M3u8::PlaylistItem.new(uri: locate_file(file))
      end
      IO.binwrite("playlists/#{name}.m3u", playlist.to_s)
    end
  end

  def unescape(str)
    # for some reason, the encoding of Apple iTunes playlist PLIST
    # doesn't encode/decode '+', so we need to ensure that we preserve it
    CGI.unescape(str.gsub('+', '%2b'))
  end

  def trim_prefix_and_unescape(str, opts)
    opts[:new_root] + unescape(str).sub(opts[:old_root], "")
  end

  def locate_file2(path, depth, candidates)
    return [path] if depth.zero?

    candidates = locate_file2(path.parent, depth-1, candidates)

    new_candidates = []
    candidates.each do |candidate|
      new_candidates << candidate.entries.select do |x|
        x.basename.to_s.downcase.unicode_normalize == path.basename.to_s.downcase.unicode_normalize
      end.map { |x| candidate + x }
    end

    new_candidates
  end

  def locate_file(filename)
    return filename if File.exists?(filename)
    candidates = locate_file2(Pathname.new(filename), 3, [])

    case candidates.size
    when 0
      puts "No candidates found for #{filename}"
      filename
    when 1
      candidates[0]
    else
      puts "More than one candidate for #{filename}. Picking first"
      candidates[0]
    end
  end
end

Exporter.new("library.xml", options: opts).run
