# -*- coding: utf-8 -*-

Plugin.create :load_more do

    UserConfig[:load_more_timeline_retrieve_count] ||= 20
    UserConfig[:load_more_reply_retrieve_count] ||= 20
    UserConfig[:load_more_list_retrieve_count] ||= 20
    UserConfig[:load_more_favorite_retrieve_count] ||= 20
    UserConfig[:load_more_usertimeline_retrieve_count] ||= 20

    settings('load more') do
      settings('一度に取得するつぶやきの件数(1-200)') do
        adjustment('タイムライン', :load_more_timeline_retrieve_count, 1, 200)
        adjustment('リプライ', :load_more_reply_retrieve_count, 1, 200)
        adjustment('リスト', :load_more_list_retrieve_count, 1, 200)
        adjustment('ユーザータイムライン', :load_more_usertimeline_retrieve_count, 1, 200)
        if UserConfig[:favorites_list_retrieve_count]
          adjustment('お気に入り', :load_more_favorite_retrieve_count, 1, 200)
        end
      end
    end

  command(
    :load_more,
    name: 'load more',
    condition: lambda{ |opt| 
      if opt.widget.slug == :home_timeline or
         opt.widget.slug == :mentions or
         opt.widget.slug =~ /list_@.+\/.+/ or
         opt.widget.parent.slug =~ /usertimeline_.+/ or
         opt.widget.slug == :own_favorites_list or
         opt.widget.parent.slug =~ /favorites_list_.+/
        true
      else
        false
      end
    },
    visible: true,
    role: :timeline) do |opt|
      twitter = Enumerator.new{|y|
        Plugin.filtering(:worlds, y)
      }.find{|world|
        world.class.slug == :twitter
      }
      if opt.widget.slug == :home_timeline
        params = {
          count: [UserConfig[:load_more_timeline_retrieve_count], 200].min,
          max_id: opt.messages.first[:id] - 1,
          tweet_mode: 'extended'.freeze
        }
        twitter.home_timeline(params).next{ |messages|
          Plugin.call(:update, twitter, messages)
          Plugin.call(:mention, twitter, messages.select{ |m| m.to_me? })
          Plugin.call(:mypost, twitter, messages.select{ |m| m.from_me? })
        }

      elsif opt.widget.slug == :mentions
        params = {
          count: [UserConfig[:load_more_reply_retrieve_count], 200].min,
          max_id: opt.messages.first[:id] - 1,
          tweet_mode: 'extended'.freeze
        }
        twitter.mentions(params).next{ |messages|
          Plugin.call(:update, twitter, messages)
          Plugin.call(:mention, twitter, messages)
          Plugin.call(:mypost, twitter, messages.select{ |m| m.from_me? })
        }.terminate("load_more: reply の追加取得に失敗しました")

      elsif opt.widget.slug =~ /list_@(.+?)\/(.+)/
        params = {
          owner_screen_name: opt.messages.first.user[:idname],
          slug: $2,
          max_id: opt.messages.first[:id] - 1,
          count: [UserConfig[:load_more_list_retrieve_count], 200].min,
          include_rts: 1,
          tweet_mode: 'extended'.freeze
        }
        twitter.list_statuses(params).next { |messages|
          timeline(opt.widget.slug) << messages
        }.terminate("load_more: list の追加取得に失敗しました")

      elsif opt.widget.parent.slug =~ /usertimeline_(.+)_.+_.+_.+/
        params = {
          # profile-http://twitter.com/username -> username
          screen_name: $1.split('/').last,
          max_id: opt.messages.first[:id] - 1,
          count: [UserConfig[:load_more_usertimeline_retrieve_count], 200].min,
          include_rts: 1,
          tweet_mode: 'extended'.freeze
        }
        twitter.user_timeline(params).next { |messages|
          timeline(opt.widget.slug) << messages
        }.terminate("load_more: usertimeline の追加取得に失敗しました")

      elsif opt.widget.slug == :own_favorites_list
        screen_name = twitter.user_obj[:idname]
        Plugin.call(:retrieve_favorites_list,
                    twitter,
                    screen_name,
                    opt.widget.slug,
                    {
                      count: [UserConfig[:load_more_favorite_retrieve_count], 200].min,
                      max_id: opt.messages.first[:id] - 1,
                      tweet_mode: 'extended'.freeze
                    } )

      elsif opt.widget.parent.slug =~ /favorites_list_(.+)_.+_.+_.+/
        # profile-http://twitter.com/username -> username
        screen_name = $1.split('/').last
        Plugin.call(:retrieve_favorites_list,
                    twitter,
                    screen_name,
                    opt.widget.slug,
                    {
                      count: [UserConfig[:load_more_favorite_retrieve_count], 200].min,
                      max_id: opt.messages.first[:id] - 1,
                      tweet_mode: 'extended'.freeze
                    } )

      end
    end

end

