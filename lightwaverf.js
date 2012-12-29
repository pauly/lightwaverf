/*
 * Simple node.js utility to read instance energy usage from lightwaverf energy monitor
 * I found the original code here:
 * http://quilowhat.tumblr.com/post/21094672763/energy-monitoring-with-lightwaverf-and-node-js
 * and am tweaking it to my requirements...
 */
var dgram = require( 'dgram' );
var server = dgram.createSocket( 'udp4' );
var winston = require( 'winston' );
winston.add( winston.transports.File, { filename: '/home/pi/lightwaverf.log' } );
// winston.remove( winston.transports.Console );
server.on( 'message', function ( msg, rinfo ) {
  if ( /W=(\d+),(\d+),(\d+),(\d+)/.exec( msg )) {
    // console.log( { usage: parseInt( RegExp.$1 ) } );
    winston.info( { usage: parseInt( RegExp.$1 ), max: parseInt( RegExp.$2 ), today: parseInt( RegExp.$3 ) } );
  }
} );
server.on( 'listening', function ( ) {
  var address = server.address( );
  console.log( 'server listening ' + address.address + ':' + address.port );
} );
server.bind( 9761 );
var client = dgram.createSocket( 'udp4' );
var msgid = 0;
setInterval( function ( client ) {
 var message = new Buffer(( msgid ++ ) + ',@?W', 'ascii' );
 client.send( message, 0, message.length, 9760, '192.168.0.14' );
}, 60000, client );

