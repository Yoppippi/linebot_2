class LinebotController < ApplicationController
  require 'line/bot'  
  require 'open-uri'
  require 'kconv'
  require 'rexml/document'

  protect_from_forgery :except => [:callback]

  def callback
    body = request.body.read
    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, signature)
      return head :bad_request
    end
    events = client.parse_events_from(body)
    events.each { |event|
      case event
      when Line::Bot::Event::Message
        case event.type
        when Line::Bot::Event::MessageType::Text
          input = event.message['text']
          url  = "https://www.drk7.jp/weather/xml/13.xml"
          xml  = open( url ).read.toutf8
          doc = REXML::Document.new(xml)
          xpath = 'weatherforecast/pref/area[4]/'
          min_per = 30
          case input
          when /.*(今日|きょう).*/
            per06to12 = doc.elements[xpath + 'info/rainfallchance/period[2]l'].text
            per12to18 = doc.elements[xpath + 'info/rainfallchance/period[3]l'].text
            per18to24 = doc.elements[xpath + 'info/rainfallchance/period[4]l'].text
            if per06to12.to_i >= min_per || per12to18.to_i >= min_per || per18to24.to_i >= min_per
              push =
                "今日は雨が降りそうです。\n降水確率はこんな感じです。\n　  6〜12時　#{per06to12}％\n　12〜18時　 #{per12to18}％\n　18〜24時　#{per18to24}％"
            else
              push =
                "今日は雨が降らない予定です。\n降水確率はこんな感じです。\n　  6〜12時　#{per06to12}％\n　12〜18時　 #{per12to18}％\n　18〜24時　#{per18to24}％"
            end
          when /.*(明日|あした).*/
            per06to12 = doc.elements[xpath + 'info[2]/rainfallchance/period[2]'].text
            per12to18 = doc.elements[xpath + 'info[2]/rainfallchance/period[3]'].text
            per18to24 = doc.elements[xpath + 'info[2]/rainfallchance/period[4]'].text
            if per06to12.to_i >= min_per || per12to18.to_i >= min_per || per18to24.to_i >= min_per
              push =
                "明日は雨が降りそうです\n今のところ降水確率はこんな感じです。\n　  6〜12時　#{per06to12}％\n　12〜18時　 #{per12to18}％\n　18〜24時　#{per18to24}％\nまた明日の朝の最新の天気予報で雨が降りそうだったら教えるね！"
            else
              push =
                "明日は雨が降らない予定です"
            end
          when /.*(明後日|あさって).*/
            per06to12 = doc.elements[xpath + 'info[3]/rainfallchance/period[2]l'].text
            per12to18 = doc.elements[xpath + 'info[3]/rainfallchance/period[3]l'].text
            per18to24 = doc.elements[xpath + 'info[3]/rainfallchance/period[4]l'].text
            if per06to12.to_i >= min_per || per12to18.to_i >= min_per || per18to24.to_i >= min_per
              push =
                "明後日は雨が降りそうです。"
            else
              push =
                "明後日は雨が降らない予定です"
            end 
          when /.*(怪しい人|あやしいひと).*/
            push =
              "近くのコンビニエンスストアでiTunesのプリペイドカードを買うのを手伝ってもらえますか？"
          when /.*(いいえ|いや|NO).*/
            push =
              "お願いです、そこをなんとか"
          when /.*(はい|いいよ|わかった|分かった|ok).*/
            push =
              "ありがとう、５万円分のプリペイドカードを買ってきて欲しい、お金は明日振り込みで大丈夫かな？"
          when /.*(なんまい|何枚).*/
            push =
              "３枚欲しいけど大丈夫かな？"
          when /.*(大丈夫|だいじょうぶ).*/
            push =
              "ありがとう、買ったら裏の番号を教えてね。"
          when /.*(おはよう|こんにちは|こんばんわ|こんばんは|こんにちわ).*/
            push =
              "你好!"
          when /.*(ありがとう|さんきゅー).*/
            push =
              "礼には及びません"
          else
            push =
              "名前を呼んでくれると怪しい発言をします。\n天気についても答えます。"
          end
        else
          push = "テキスト以外は分からんな"
        end
        message = {
          type: 'text',
          text: push
        }
        client.reply_message(event['replyToken'], message)
      when Line::Bot::Event::Follow
        line_id = event['source']['userId']
        User.create(line_id: line_id)
      when Line::Bot::Event::Unfollow
        line_id = event['source']['userId']
        User.find_by(line_id: line_id).destroy
      end
    }
    head :ok
  end

  private

  def client
    @client ||= Line::Bot::Client.new { |config|
      config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
      config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
    }
  end
end
