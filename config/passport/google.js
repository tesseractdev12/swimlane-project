'use strict';

/**
 * Module dependencies.
 */

const mongoose = require('mongoose');
const GoogleStrategy = require('passport-google-oauth').OAuth2Strategy;
const config = require('../');
const User = mongoose.model('User');

/**
 * Expose
 */

module.exports = new GoogleStrategy(
  {
    clientID: config.google.clientID,
    clientSecret: config.google.clientSecret,
    callbackURL: config.google.callbackURL
  },
  async function(accessToken, refreshToken, profile, done) {
    const options = {
      criteria: { 'google.id': profile.id }
    };
    try {
      let user = await User.load(options);
      if (!user) {
        user = new User({
          name: profile.displayName,
          email: profile.emails[0].value,
          username: profile.username,
          provider: 'google',
          google: profile._json
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
