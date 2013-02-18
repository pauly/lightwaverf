var express = require('express');
var routes = require('./routes');
var automation = require('./routes/automation');
var path = require('path');
var passport = require('passport');
var util = require('util');
var TwitterStrategy = require('passport-twitter').Strategy;

// Passport session setup.
//   To support persistent login sessions, Passport needs to be able to
//   serialize users into and deserialize users out of the session.  Typically,
//   this will be as simple as storing the user ID when serializing, and finding
//   the user by ID when deserializing.  However, since this example does not
//   have a database of user records, the complete Twitter profile is serialized
//   and deserialized.
passport.serializeUser( function( user, cb ) {
  cb( null, user );
} );

passport.deserializeUser( function( obj, cb ) {
  cb( null, obj );
} );

// Use the TwitterStrategy within Passport.
//   Strategies in passport require a `verify` function, which accept
//   credentials (in this case, a token, tokenSecret, and Twitter profile), and
//   invoke a callback with a user object.
if ( process.env.TWITTER_CONSUMER_KEY && process.env.TWITTER_CONSUMER_SECRET ) {
  passport.use( new TwitterStrategy( {
      consumerKey: process.env.TWITTER_CONSUMER_KEY,
      consumerSecret: process.env.TWITTER_CONSUMER_SECRET,
      // callbackURL: "http://127.0.0.1:3000/auth/twitter/callback"
      callbackURL: 'http://pi.clarkeology.com:3000/auth/twitter/callback'
    },
    function(token, tokenSecret, profile, done) {
      // asynchronous verification, for effect...
      process.nextTick(function () {
        
        // To keep the example simple, the user's Twitter profile is returned to
        // represent the logged-in user.  In a typical application, you would want
        // to associate the Twitter account with a user record in your database,
        // and return that user instead.
        return done(null, profile);
      });
    }
  ));
}

var app = express();

// configure Express
app.configure(function() {
  app.set('views', __dirname + '/views');
  app.set('view engine', 'ejs');
  app.use(express.logger());
  app.use(express.cookieParser());
  app.use(express.bodyParser());
  app.use(express.methodOverride());
  app.use(express.session({ secret: 'keyboard cat' }));
  // Initialize Passport!  Also use passport.session() middleware, to support
  // persistent login sessions (recommended).
  app.use(passport.initialize());
  app.use(passport.session());
  app.use(app.router);
  app.use(express.static(__dirname + '/public'));
});

// $ustream = json_decode( file_get_contents( 'http://api.ustream.tv/json/channel/paulypopex/getValueOf/status?key=' + process.env.USTREAM_KEY )); 

app.get( '/', routes.index );
app.get( '/login', routes.login );
app.get( '/automation', ensureAuthenticated, automation.index );
app.get( '/automation/:room/:device/:status?.js', ensureAuthenticated, automation.json );
// app.get( '/automation/:room/:device?/:status?', ensureAuthenticated, automation.device );

// GET /auth/twitter
//   Use passport.authenticate() as route middleware to authenticate the
//   request.  The first step in Twitter authentication will involve redirecting
//   the user to twitter.com.  After authorization, the Twitter will redirect
//   the user back to this application at /auth/twitter/callback
app.get( '/auth/twitter',
  passport.authenticate( 'twitter' ),
  function( req, res ) {
    // The request will be redirected to Twitter for authentication, so this
    // function will not be called.
  }
);

// GET /auth/twitter/callback
//   Use passport.authenticate() as route middleware to authenticate the
//   request.  If authentication fails, the user will be redirected back to the
//   login page.  Otherwise, the primary route function function will be called,
//   which, in this example, will redirect the user to the home page.
app.get( '/auth/twitter/callback', 
  passport.authenticate( 'twitter', { failureRedirect: '/login' } ),
  function( req, res ) {
    res.redirect( req.session.page || '/' );
} );

app.get( '/logout', function( req, res ) {
  req.logout( );
  res.redirect( '/' );
} );

app.listen( process.env.port || 3000 );

// Simple route middleware to ensure user is authenticated.
//   Use this route middleware on any resource that needs to be protected.  If
//   the request is authenticated (typically via a persistent login session),
//   the request will proceed.  Otherwise, the user will be redirected to the
//   login page.
function ensureAuthenticated( req, res, next ) {
  req.session.page = req.route.path;
  if ( ! ( process.env.TWITTER_CONSUMER_KEY && process.env.TWITTER_CONSUMER_SECRET )) {
    console.error( 'you need TWITTER_CONSUMER_KEY and TWITTER_CONSUMER_SECRET in your env vars. see config/default.sh.sample' );
    return next( );
  }
  if ( req.isAuthenticated( )) {
    return next( );
  }
  // res.redirect( '/login' );
  res.redirect( '/auth/twitter' );
}
