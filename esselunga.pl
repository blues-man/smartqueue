#!/usr/bin/perl -w
############################################################################
#    Esselunga Slot checker                                                #
#    Copyright (C) 2020 Natale Vinto                                       #
#    ebballon@gmail.com                                                    #
#                                                                          #
#    This program is free software; you can redistribute it and#or modify  #
#    it under the terms of the GNU General Public License as published by  #
#    the Free Software Foundation; either version 2 of the License, or     #
#    (at your option) any later version.                                   #
#                                                                          #
#    This program is distributed in the hope that it will be useful,       #
#    but WITHOUT ANY WARRANTY; without even the implied warranty of        #
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         #
#    GNU General Public License for more details.                          #
#                                                                          #
#    You should have received a copy of the GNU General Public License     #
#    along with this program; if not, write to the                         #
#    Free Software Foundation, Inc.,                                       #
#    59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             #
############################################################################


use strict;
use warnings;

use feature 'say';

use LWP::UserAgent;
use HTTP::Request::Common qw(POST);
use HTTP::Cookies;
use HTML::Entities;
use Getopt::Std;
use Encode;
use MIME::Lite;
use MIME::Base64;
use Authen::SASL;
use JSON::MaybeXS;
use DBI;




my $DEBUG = 1;
my $smtp_server = '';
my $smtp_user = '';
my $smtp_pass = '';
my $smtp_port = '';

my $email_from = '';

my %options = ();
my $username = '';
my $password = '';
my $email = '';
my $city = '';

if ($ENV{USERNAME} && $ENV{PASSWORD}) {

  $username = $ENV{USERNAME};
  $password = $ENV{PASSWORD};
  
  if ($ENV{EMAIL}){
    $email = $ENV{EMAIL}; 
  }
} else {
    getopt( 'upec', \%options );

    if ( !$options{u} || !$options{p} ) {
        say "Opzioni: -u USERNAME -p PASSWORD [-e EMAIL]\n";
        say "Esempio: esselunga.pl -u esempio\@gmail.com -p password";
        say "Esempio:  esselunga.pl -u esempio\@gmail.com -p password -e esempio\@gmail.com,altro\@gmail.com -c milano";
        exit 1;
    }
    $username = $options{u};
    $password = $options{p};
    
    if ($options{e}){
        $email = $options{e};
    }
    
    if ($options{c}){
        $city = "-".$options{c};
    }
}

my $dbfile = "esselunga$city.sqlite";
my $dbh =
    DBI->connect( "dbi:SQLite:dbname=$dbfile", "", "",
    { RaiseError => 1 } )
or die $DBI::errstr;


my $stmt = qq(CREATE TABLE IF NOT EXISTS slots
(   start_time  DATETIME NOT NULL UNIQUE,
    email_sent    INT     NOT NULL,
    text          VARCHAR(50)););

my $rv = $dbh->do($stmt);
if($rv < 0) {
    say $DBI::errstr;
} else {
    say "Database structure Ready";
}


my $url =
'https://www.esselunga.it/area-utenti/applicationCheck?appName=esselungaEcommerce&daru=https%3A%2F%2Fwww.esselungaacasa.it%3A443%2Fecommerce%2Fnav%2Fauth%2Fsupermercato%2Fhome.html%3F&loginType=light';


sub send_mail {
    my ($emails,$body) = @_;
    my @emails = split(/,/, $emails);
    my $to = $emails[0];
    my $cc = '';
    for (my $i = 1; $i < scalar(@emails); $i++){ 
        $cc.="$emails[$i],";
    }
    my $from = $email_from;
    my $subject = 'Slot disponibili';
    my $message = $body;
    
    
    my $msg = MIME::Lite->new(
                    From     => $from,
                    To       => $to,
                    Type     => 'TEXT',
                    Bcc      => $cc,
                    Subject  => $subject,
                    Data     => $message
                    );
                    
    #$msg->attr("content-type" => "text/html");         
    $msg->send('smtp', $smtp_server, AuthUser=>$smtp_user, AuthPass=>$smtp_pass,  SSL => 1, Port => $smtp_port  );
    say "Email Inviata!";
}


    



my $ua        = LWP::UserAgent->new();
my $cookiejar = HTTP::Cookies->new();
$ua->cookie_jar($cookiejar);
$ua->agent('Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.; Trident/5.0)');

my $res     = $ua->get($url);
my $content = '';

unless ( $res->is_success ) {
    say "Non posso raggiungere il sito esselunga.it, skipping";
    exit 1;

}

say "Homepage OK";

$content = $res->content if $DEBUG;

my $csrf = '';

$ua->default_header( 'Referer' =>
'https://www.esselunga.it/area-utenti/applicationCheck?appName=esselungaEcommerce&daru=https%3A%2F%2Fwww.esselungaacasa.it%3A443%2Fecommerce%2Fnav%2Fauth%2Fsupermercato%2Fhome.html%3F&loginType=light'
);
$ua->default_header( 'FETCH-CSRF-TOKEN' => '1' );
push @{ $ua->requests_redirectable }, 'POST';

$res = POST 'https://www.esselunga.it/area-utenti/csrfjs';

my $resp = $ua->request($res);
$content = $resp->content;

if ( $content =~ /^X-CSRF-TOKEN:(.*)$/ ) {
    $csrf = $1;
}
else {
    say "Non posso estrapolare il token CSRF, skipping";
    say $content if $DEBUG;
    exit 1;
}

say "Token: $csrf" if $DEBUG;

$ua->default_header( 'Referer' =>
'https://www.esselunga.it/area-utenti/applicationCheck?appName=esselungaEcommerce&daru=https%3A%2F%2Fwww.esselungaacasa.it%3A443%2Fecommerce%2Fnav%2Fauth%2Fsupermercato%2Fhome.html%3F&loginType=light'
);

$res = POST 'https://www.esselunga.it/area-utenti/loginExt',
  [
    username => $username,
    password => $password,
    daru =>
'https://www.esselungaacasa.it:443/ecommerce/nav/auth/supermercato/home.html',
    dare =>
'https://www.esselunga.it/area-utenti/applicationCheck?appName=esselungaEcommerce&daru=https%3A%2F%2Fwww.esselungaacasa.it%3A443%2Fecommerce%2Fnav%2Fauth%2Fsupermercato%2Fhome.html%3F&loginType=light',
    appName        => 'esselungaEcommerce',
    promo          => '',
    'X-CSRF-TOKEN' => $csrf
  ];

$resp    = $ua->request($res);
$content = $resp->content;

unless ( $resp->is_success ) {
    say "Non posso effettuare il login, skipping";
    say $content if $DEBUG;
    exit 1;
}

say "Login OK";
my $cookies = $cookiejar->as_string;
my $xsfr    = '';

if ( $cookies =~ /XSRF-ECOM-TOKEN=(.*?);/ ) {
    $xsfr = $1;
    say "XSFR: $xsfr" if $DEBUG;
}

$ua->default_header( 'Content-Type' => 'application/json' );
$ua->default_header( 'X-XSRF-TOKEN' => $xsfr );

$res = $ua->get(
    'https://www.esselungaacasa.it/ecommerce/resources/auth/slot/status');
$content = $res->content;

unless ( $res->is_success ) {
    say "Non posso verificare gli slot, skipping";
    say $content if $DEBUG;
    exit 1;
}

my $ok = 0;
my $slots = '';
my $html = '';

my $records = decode_json($content);
my $json = $records->{slots};


for my $hashref (@{$json}) {
    #foreach my $key (keys %{$hashref}){
        my $status     = $hashref->{viewStatus};
        my $start_time = $hashref->{startTime};
        my $end_time   = $hashref->{endTime};
        my $s_status   = $hashref->{status};
        
        say "$status - $start_time - $end_time $s_status" if $DEBUG;
        
    if (   $status ne 'ESAURITA'
        && $status ne 'INIBITA'
        && $s_status ne 'DISABLED' )
    {

        my $start_time_date = '';
        my $start_time_hour = '';
        my $end_time_date = '';
        my $end_time_hour = '';
        if ($start_time =~ /(.*)T(.*):00:00.000\+0000/){
            $start_time_date = $1;
            $start_time_hour = $2;
            $start_time_hour+=2;
        }
        if ($end_time =~ /(.*)T(.*):00:00.000\+0000/){
            $end_time_date = $1;
            $end_time_hour = $2;
            $end_time_hour+=2;
        }
        my $slots = "SLOT: $status - Data Inizio: $start_time_date Ore: $start_time_hour:00,  Data Fine: $end_time_date Ore: $end_time_hour:00";
        
        say $slots;
        $ok = 1;

        my $sth = $dbh->prepare("INSERT OR IGNORE INTO slots(start_time, email_sent, text) VALUES(?,?,?)");
        $sth->execute($start_time, 0, $slots) or die $DBI::errstr;
    }

}

say "Check slot completo";
if ($ok) {
    say "BINGO!";
    
    my $sth = $dbh->prepare("SELECT text FROM slots WHERE email_sent = 0")
            or die "prepare statement failed: $dbh->errstr()";
    
    $sth->execute() or die "execution failed: $dbh->errstr()"; 
 
    my $text;
    my $message = '';
    while($text = $sth->fetchrow()){
        $message .= "$text\n";                   
    }
    
    my $send_text = "Ciao,\nSono liberi degli slot:\n\n" . $message . "\nBuona spesa!\n";
    
    
    if ($email ne ''){
            send_mail($email, $send_text);
            
            $sth = $dbh->prepare('UPDATE slots set email_sent = 1 WHERE start_time IN (SELECT start_time FROM slots WHERE email_sent = 0);');
            $sth->execute() or die $DBI::errstr;
            
    }

} else {
    say "Nessun nuovo slot disponibile, riprovare";
}


