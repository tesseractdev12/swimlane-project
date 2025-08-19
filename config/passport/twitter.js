'use strict';

/**
 * Module dependencies.
 */

const mongoose = require('mongoose');
const TwitterStrategy = require('passport-twitter').Strategy;
const config = require('../');
const User = mongoose.model('User');

/**
 * Expose
 */

module.exports = new TwitterStrategy(
  {
    consumerKey: config.twitter.clientID,
    consumerSecret: config.twitter.clientSecret,
    callbackURL: config.twitter.callbackURL
  },
  async function(accessToken, refreshToken, profile, done) {
    const options = {
      criteria: { 'twitter.id_str': profile.id }
    };
    try {
      let user = await User.load(options);
      if (!user) {
        user = new User({
          name: profile.displayName,
          username: profile.username,
          provider: 'twitter',
          twitter: profile._json
        });
        await user.save();
      }
      return done(null, user);
    } catch (err) {
      if (err) console.log(err);
      return done(err);
    }
  }
);
