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
      if opt.widget.slug == :home_timeline
        params = {
          count: [UserConfig[:load_more_timeline_retrieve_count], 200].min,
          max_id: opt.messages.first[:id] - 1
        }
        Service.primary.home_timeline(params).next{ |messages|
          Plugin.call(:update, Service, messages)
          Plugin.call(:mention, Service, messages.select{ |m| m.to_me? })
          Plugin.call(:mypost, Service, messages.select{ |m| m.from_me? })
        }

      elsif opt.widget.slug == :mentions
        params = {
          count: [UserConfig[:load_more_reply_retrieve_count], 200].min,
          max_id: opt.messages.first[:id] - 1
        }
        Service.primary.mentions(params).next{ |messages|
          Plugin.call(:update, Service, messages)
          Plugin.call(:mention, Service, messages)
          Plugin.call(:mypost, Service, messages.select{ |m| m.from_me? })
        }.terminate()

      elsif opt.widget.slug =~ /list_@(.+?)\/(.+)/
        params = {
          owner_screen_name: $1,
          slug: $2,
          max_id: opt.messages.first[:id] - 1,
          count: [UserConfig[:load_more_list_retrieve_count], 200].min,
          include_rts: 1
        }
        Service.primary.list_statuses(params).next { |messages|
          timeline(opt.widget.slug) << messages
        }.terminate()

      elsif opt.widget.parent.slug =~ /usertimeline_(.+)_.+_.+_.+/
        params = {
          screen_name: $1,
          max_id: opt.messages.first[:id] - 1,
          count: [UserConfig[:load_more_usertimeline_retrieve_count], 200].min,
          include_rts: 1
        }
        Service.primary.user_timeline(params).next { |messages|
          timeline(opt.widget.slug) << messages
        }.terminate()

      elsif opt.widget.slug == :own_favorites_list
        screen_name = Service.primary.user_obj[:idname]
        Plugin.call(:retrieve_favorites_list,
                    Service,
                    screen_name,
                    opt.widget.slug,
                    {
                      count: [UserConfig[:load_more_favorite_retrieve_count], 200].min,
                      max_id: opt.messages.first[:id] - 1
                    } )

      elsif opt.widget.parent.slug =~ /favorites_list_(.+)_.+_.+_.+/
        screen_name = $1
        Plugin.call(:retrieve_favorites_list,
                    Service,
                    screen_name,
                    opt.widget.slug,
                    {
                      count: [UserConfig[:load_more_favorite_retrieve_count], 200].min,
                      max_id: opt.messages.first[:id] - 1
                    } )

      end
    end

end

