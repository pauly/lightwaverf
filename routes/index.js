
/*
 * GET home page.
 */

exports.index = function( req, res ) {
  var summary = '';
  var sys = require('sys')
  var exec = require('child_process').exec;
  function uptime(error, stdout, stderr) {
    console.log(stdout)
    res.render( 'index', {
      title: 'raspberry pi hömepage',
      user: req.user,
      ustream: 'offline',
      uptime: stdout
    } );
  }
  exec( "uptime", uptime );
};

/*
 * GET login page.
 */

exports.login = function( req, res ) {
  res.render( 'login', {
    title: 'lögin',
    user: req.user
  } );
};
