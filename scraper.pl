#!/usr/bin/perl

use URI;
use WWW::Mechanize;
use HTML::TreeBuilder;
use Database::DumpTruck;
use Encode qw/decode_utf8/;

use strict;
use warnings;

my $baseurl = 'http://www.dusevnevlastnictvo.gov.sk';

my $root = new URI($baseurl . '/Default.aspx?menu=1400_1');
my $mech = new WWW::Mechanize;
my $dt = new Database::DumpTruck(
    { dbname => 'data.sqlite', table => 'swdata' });

$mech->get($root);
my $response =
    $mech->click('ctl00$ContentPlaceHolder1$m_Documents$m_SelectAll')->content;
my $tree = HTML::TreeBuilder->new_from_content(decode_utf8($response));

my @results = $tree->find_by_attribute('class', 'tablegrid')->find('tr');

foreach my $tr (@results) {
    my $class = $tr->attr('class') // '';
    next if ($class !~ /^tablerow/);

    my @tds = $tr->find('td');

    my %row;

    $row{'nazov'} = $tds[0]->as_trimmed_text;
    $row{'datum'} = $tds[1]->as_trimmed_text;
    $row{'kategoria'} = $tds[2]->as_trimmed_text;
    $row{'jazyk'} = $tds[3]->as_trimmed_text;
    $row{'nazov_prilohy'} = $tds[4]->as_trimmed_text;
    $row{'url_prilohy'} = $baseurl . $tds[4]->find('a')->attr('href');
    (
        $row{'nazov2'},
        $row{'pravny_odbor'},
        $row{'spisova_znacka'}
    ) =
        $row{'nazov'} =~ m/^(.*\d{4})\..*: (.*)Spis.*: (.*)$/;

    $root = $baseurl . $tds[0]->find('a')->attr('href');
    $mech->get($root);
    $tree = HTML::TreeBuilder->new_from_content($mech->content());

    my @trs = $tree->find_by_attribute('class', 'desctable')->find('tr');
    my $code_tr = $trs[9];
    my @code_tds = $code_tr->find('td');
    $row{'kod_dokumentu'} = $code_tds[1]->as_trimmed_text;

    $dt->insert (\%row);
}
