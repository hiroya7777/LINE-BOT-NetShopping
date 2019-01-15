class LinebotsController < ApplicationController
  require 'line/bot'

  protect_from_forgery :except => [:callback]

  def callback
    body = request.body.read
    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, signature)
      error 400 do 'Bad Request' end
    end
    events = client.parse_events_from(body)
    events.each do |event|
       case event
       when Line::Bot::Event::Message
         case event.type
         when Line::Bot::Event::MessageType::Text
           input = event.message['text']
           message = search_and_create_message(input)
           client.reply_message(event['replyToken'],messages)
         end
       end
    end
    head :ok
end

private

def client
  @client || = Line::Bot::Client.new do |config|
    config.channel_secret = ENV['LINE_CHANNEL_SECRET']
    config.channel_token = ENV['LINE_CHANEL_TOKEN']
  end
end

def search_and_create_messages(input)
  Amazon::Ecs.debug = true

  res1 = Amazon::Ecs.item_search(
    input,
    search_index: 'All',
    response_group: 'BrowseNodes',
    country: 'jp'
  )
  browse_node_no = res1.items.first.get('BrowseNodes/BrowseNode/BrowseNodeId')
  res2 = Amazon::Ecs.item_search(
    input,
    browse_node: browse_node_no,
    response_group: 'ItemAttributes, Images, Offers',
    country: 'jp',
    sort: 'salesrank'
  )
  make_reply_content(res2)
end

def make_reply_content(res2)
    {
      "type": "flex",
      "altText": "This is a Flex Message",
      "contents":
      {
        "type": "carousel",
        "contents": [
          make_part(res2.items[0], 1),
          make_part(res2.items[1], 2),
          make_part(res2.items[2], 3)
        ]
      }
    }
  end

def make_part(item, rank)
  title = item.get('ItemAttributes/Title')
  price = item.get('ItemAttributes/ListPrice/FormatterPrice') || item.get('OfferSummary/LowestNewPrice/FormattedPrice')
  url = bitly_shorten(item.get('DatailPageURL')
  {
   "type": "bubble",
   "hero":{
     "type": "image",
     "size": "full"
     "aspectRatio": "20:13",
     "aspecMode" : "cover" ,
     "url": "image"
  },
  "body":
  {
    "type": "box",
    "layout": "vertical",
    "spacing": "sm",
    "contents": [
  {
    "type": "text"
    "text": "#(rank)",
    "wrap": true,
    "margin": "md",
    "color": "#ff5551",
    "flex": 0
  },
   {
     "type": "text",
     "text": title,
     "wrap": true,
     "weight": "bold",
     "size": "lg"
   },
    "type": "box",
    "layout": "baseline",
    "contens": [
      {
      "type": "text",
      "text": price,
      "wrap": true,
      "weight": "bold",
      "flex": 0
      }
    ]
  }
    ]
  },
  "footer": {
    "type": "box",
    "layout": "vertical",
    "spacing": "sm",
    "contents": [
      {
        "type": "button",
        "style": "primary",
        "action": {
          "type": "url",
          "label": "Amazon商品ページへ",
          "url": url
                   }
      }
                 ]
        }
    }
 end
end
