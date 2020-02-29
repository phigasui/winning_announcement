include("./WinningAnnouncement.jl")

using DotEnv
DotEnv.config()

const TWEET_ID = 1229402085726097410

const TEMPLATE =
"""
@#{1} さん パーカー ✨
@#{2} さん ロンT white ✨
@#{3} さん ロンT black ✨

ご当選おめでとうございます🎉
"""

const RANGE = 1:3

WinningAnnouncement.authorize(
  ENV["TWITTER_CONSUMER_API_KEY"],
  ENV["TWITTER_CONSUMER_API_SECRET_KEY"],
  ENV["TWITTER_ACCESS_TOKEN"],
  ENV["TWITTER_ACCESS_TOKEN_SECRET"],
)
WinningAnnouncement.exec(TEMPLATE, TWEET_ID, RANGE)
