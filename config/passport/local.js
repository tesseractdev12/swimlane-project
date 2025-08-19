'use strict';

/**
 * Module dependencies.
 */

const mongoose = require('mongoose');
const LocalStrategy = require('passport-local').Strategy;
const User = mongoose.model('User');

/**
 * Expose
 */

module.exports = new LocalStrategy(
  {
    usernameField: 'email',
    passwordField: 'password'
  },
  async function(email, password, done) {
    const options = {
      criteria: { email: email },
      select: 'name username email hashed_password salt'
    };
    try {
      const user = await User.load(options);
      if (!user) {
        return done(null, false, { message: 'Unknown user' });
      }
      if (!user.authenticate(password)) {
        return done(null, false, { message: 'Invalid password' });
      }
      return done(null, user);
    } catch (err) {
      return done(err);
    }
  }
);
