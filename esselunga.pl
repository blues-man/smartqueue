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

use Data::Dumper;



my $DEBUG = 1;
my $VERBOSE = 0;
my $DATAPATH = '';
my $BOOKSLOT = 0;

my $smtp_server_ssl = 1;
my $smtp_server = '';
my $smtp_user = '';
my $smtp_pass = '';
my $smtp_port = '';

my $email_from = '';

my %options = ();
my $username = '';
my $password = '';
my $email = '';

my $login = 0;

my @slots;




sub fill_smtp_settings {

    if ($ENV{SMTP_SERVER}){
        $smtp_server = $ENV{SMTP_SERVER};
    }

    if ($ENV{SMTP_USER}){
        $smtp_user = $ENV{SMTP_USER};
    }

    if ($ENV{SMTP_PASS}){
        $smtp_pass = $ENV{SMTP_PASS};
    }

    if ($ENV{SMTP_PORT}){
        $smtp_port = $ENV{SMTP_PORT};
    }

    if ($ENV{EMAIL_FROM}){
        $email_from = $ENV{EMAIL_FROM};
    }

    if ($ENV{SMTP_SERVER_SSL}){
        $smtp_server_ssl = $ENV{SMTP_SERVER_SSL};
        $smtp_server_ssl = 1 if  $smtp_server_ssl !~ /\d+/;
    }

    say "Uso server SMTP: $smtp_server User: $smtp_user Port: $smtp_port Email: $email_from" if $DEBUG;
}

sub send_mail {
    my ($to, $cc, $subject, $body) = @_;

    my $from = $email_from;
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
    $msg->send('smtp', $smtp_server, AuthUser=>$smtp_user, AuthPass=>$smtp_pass,  SSL => $smtp_server_ssl, Port => $smtp_port  );
    say "Email Inviata!";
}



if ($ENV{USERNAME} && $ENV{PASSWORD}) {

  $username = $ENV{USERNAME};
  $password = $ENV{PASSWORD};
  
  if ($ENV{EMAIL}){
    $email = $ENV{EMAIL};
    fill_smtp_settings();
  }
  if ($ENV{BOOKSLOT}){
    $BOOKSLOT = $ENV{BOOKSLOT};
  }
} else {
    getopt( 'b:u:p:e:', \%options );

    if ( !$options{u} || !$options{p} ) {
        say "Opzioni: -u USERNAME -p PASSWORD [-e EMAIL]\n";
        say "Esempio: esselunga.pl -u esempio\@gmail.com -p password";
        say "Esempio: esselunga.pl -u esempio\@gmail.com -p password -e esempio\@gmail.com,altro\@gmail.com";
        say "Esempio: esselunga.pl -u esempio\@gmail.com -p password -e esempio\@gmail.com,altro\@gmail.com -b";
        say "Esempio: SMTP_SERVER=smtp.test.com SMTP_USER=test SMTP_PASS=pass SMTP_PORT=587 SMTP_SERVER_SSL=1 EMAIL_FROM=info\@test.it esselunga.pl -u esempio\@gmail.com -p password -e esempio\@gmail.com,altro\@gmail.com";
        exit 1;
    }
    $username = $options{u};
    $password = $options{p};
    
    if ($options{e}){
        $email = $options{e};
        fill_smtp_settings();
    }
    
    if ($options{b}){
        $BOOKSLOT = 1;
    }
}


if ($ENV{DEBUG}){
    $DEBUG = $ENV{DEBUG};
}

if ($ENV{VERBOSE}){
    $VERBOSE = $ENV{VERBOSE};
}

if ($ENV{DATAPATH}){
    $DATAPATH = $ENV{DATAPATH};
    if ($DATAPATH !~ m/\/$/){
        $DATAPATH = "$DATAPATH/";
    }
}

my $ua        = LWP::UserAgent->new();
my $cookiejar = HTTP::Cookies->new(
  file => $DATAPATH . "${username}_cookies.txt",
  autosave => 1,
  ignore_discard => 1
);
$ua->cookie_jar($cookiejar);
$ua->agent('Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.; Trident/5.0)');


my $dbfile = $DATAPATH . "esselunga.sqlite";
my $dbh =
    DBI->connect( "dbi:SQLite:dbname=$dbfile", "", "",
    { RaiseError => 1 } )
or die $DBI::errstr;


my $stmt = qq(CREATE TABLE IF NOT EXISTS slots
(   username      TEXT NOT NULL,
    start_time    DATETIME NOT NULL,
    end_time      DATETIME NOT NULL,
    insert_time   DATETIME NOT NULL DEFAULT (DATETIME('now')),
    email_sent    INTEGER  NOT NULL DEFAULT 0,
    slot_booked   INTEGER  NOT NULL DEFAULT 0,
    text          TEXT,
    PRIMARY KEY (username, start_time)););

my $rv = $dbh->do($stmt);
if($rv < 0) {
    say $DBI::errstr;
} else {
    say "Database structure Ready";
}

sub homepage {
    my $url =
'https://www.esselunga.it/area-utenti/applicationCheck?appName=esselungaEcommerce&daru=https%3A%2F%2Fwww.esselungaacasa.it%3A443%2Fecommerce%2Fnav%2Fauth%2Fsupermercato%2Fhome.html%3F&loginType=light';
    my $res     = $ua->get($url);
    my $content = '';

    unless ( $res->is_success ) {
        say "Non posso raggiungere il sito esselunga.it, skipping";
        say $res->content if $VERBOSE;
        exit 1;

    }

    say "Homepage OK";
    $content = $res->content if $DEBUG;

}


sub login {

    homepage();

    my $csrf = '';

    $ua->default_header( 'Referer' =>
    'https://www.esselunga.it/area-utenti/applicationCheck?appName=esselungaEcommerce&daru=https%3A%2F%2Fwww.esselungaacasa.it%3A443%2Fecommerce%2Fnav%2Fauth%2Fsupermercato%2Fhome.html%3F&loginType=light'
    );
    $ua->default_header( 'FETCH-CSRF-TOKEN' => '1' );
    push @{ $ua->requests_redirectable }, 'POST';

    my $res = POST 'https://www.esselunga.it/area-utenti/csrfjs';

    my $resp = $ua->request($res);
    my $content = $resp->content;

    if ( $content =~ /^X-CSRF-TOKEN:(.*)$/ ) {
        $csrf = $1;
    }
    else {
        say "Non posso estrapolare il token CSRF, skipping";
        say $content if $VERBOSE;
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

    unless ( $resp->is_success && $content =~ /<img src="\/html\/images\/logo-esselungaacasa.jpg" alt="Attendere">/ ) {
        say "Non posso effettuare il login, skipping";
        say $content if $VERBOSE;
        exit 1;
    }
    $login = 1;
    say "Login OK";

}


sub bookslot {
    my $json = shift;
    my $url = 'https://www.esselungaacasa.it/ecommerce/resources/auth/slot/reservation';
    $ua->default_header( 'Content-Type' => 'application/json' );
    my $res = $ua->post($url, Content => encode_json($json));
    if ( $res->is_success ) {
        say "Slot " . $json->{startTime} . " prenotato!";
        return 1;
    } else {
        say "Errore nella prenotazione slot " . $json->{startTime};
        return 0;
    }
}


my $res     = '';
my $content = '';
my $xsfr    = '';

$cookiejar ->scan(sub { 
  if ($_[1] eq 'XSRF-ECOM-TOKEN') { 
    $xsfr = $_[2]; 
  }; 
});


if ($xsfr eq ''){
    if (!$login) {
        login();
        $cookiejar ->scan(sub { 
            if ($_[1] eq 'XSRF-ECOM-TOKEN') { 
                $xsfr = $_[2]; 
            }; 
        });
    } else {
        say "Non posso estrarre il cookie XSFR";
        exit 1;
    }

}

$ua->default_header( 'Content-Type' => 'application/json' );
$ua->default_header( 'X-XSRF-TOKEN' => $xsfr );

$res = $ua->get(
    'https://www.esselungaacasa.it/ecommerce/resources/auth/slot/status');
$content = $res->content;

unless ( $res->is_success ) {
    say "Non posso verificare gli slot, skipping";
    say $content if $DEBUG;
    $cookiejar->clear;
    exit 1;
}

my $ok = 0;
my $slots = '';
my $html = '';

my $records = decode_json($content);
my $json = $records->{slots};


for my $hashref (@{$json}) {
        my $status     = $hashref->{viewStatus};
        my $start_time = $hashref->{startTime};
        my $end_time   = $hashref->{endTime};
        my $s_status   = $hashref->{status};
        
        say "$status - $start_time - $end_time $s_status" if $VERBOSE;
        
    if (   $status eq 'QUASI_ESAURITA'
        || $status eq 'DISPONIBILE')
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

        my $sth = $dbh->prepare("INSERT OR IGNORE INTO slots(start_time, end_time, username, email_sent, slot_booked, text) VALUES(?,?,?,?,?,?)");
        $sth->execute($start_time, $end_time, $username, 0, 0, $slots) or die $DBI::errstr;
    }

}

say "Check slot completo";
if ($ok) {
    say "BINGO!";
    
    my $sth = $dbh->prepare("SELECT start_time, end_time, text FROM slots WHERE email_sent = 0 AND username = '$username'")
            or die "prepare statement failed: $dbh->errstr()";
    
    $sth->execute() or die "execution failed: $dbh->errstr()"; 
 
    my ($start_time, $end_time, $text);
    my $message = '';
    while(($start_time, $end_time, $text) = $sth->fetchrow()){
        $message .= "$text\n";
        my %slotsref;
        $slotsref{startTime} = $start_time;
        $slotsref{endTime} = $end_time;

        push @slots, \%slotsref;
    }
    
    my $send_text = "Ciao,\nSono liberi degli slot:\n\n" . $message . "\nBuona spesa su https://www.esselungaacasa.it/ !\n";

    my @emails = split(/,/, $email);
    my $to = $emails[0];
    my $cc = '';
    for (my $i = 1; $i < scalar(@emails); $i++){ 
        $cc.="$emails[$i],";
    }
    
    if ($email ne '' && $message ne ''){
            send_mail($to, $cc, "Slot disponibili", $send_text);
            
            $sth = $dbh->prepare("UPDATE slots set email_sent = 1 WHERE start_time IN (SELECT start_time FROM slots WHERE email_sent = 0 AND slot_booked = 0 AND username = '$username');");
            $sth->execute() or die $DBI::errstr;  
    }

    if ($BOOKSLOT) {
        foreach my $hashref (@{slots}){            
            if ($message ne ''){
                    my $sth = $dbh->prepare("SELECT start_time  FROM slots WHERE slot_booked = 1 AND username = '$username'") or die "prepare statement failed: $dbh->errstr()";
                    $sth->execute() or die "execution failed: $dbh->errstr()"; 

                    my $start_time;
                    my $book = 1;
                    while(($start_time = $sth->fetchrow())){
                        my $dt1 = `date -d $hashref->{startTime} +%s` ;
                        $dt1 =~ s/\n//g;
                        my $dt2 = `date -d $start_time +%s` ;
                        $dt2 =~ s/\n//g;

                        $dt1 > $dt2 ? $book = 0 : $book = 1;
                    }
                    if ($book && bookslot($hashref)){
                        $sth = $dbh->prepare("UPDATE slots set slot_booked = 1 WHERE start_time = '$hashref->{startTime}' AND username = '$username';");
                        $sth->execute() or die $DBI::errstr;
                        send_mail($to, '', "Slot prenotato!", "Slot ". $hashref->{startTime} . " - " . $hashref->{endTime}) if $email ne '';
                        last;
                    }
            }
        }
    }
} else {
    say "Nessuno nuovo slot disponibile, riprovare";
}
