# --
# Copyright (C) 2001-2016 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

use Kernel::Language;

# get selenium object
my $Selenium = $Kernel::OM->Get('Kernel::System::UnitTest::Selenium');

$Selenium->RunTest(
    sub {

        # get needed objects
        my $Helper          = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');
        my $ConfigObject    = $Kernel::OM->Get('Kernel::Config');
        my $SysConfigObject = $Kernel::OM->Get('Kernel::System::SysConfig');

        # enable meta floaters for AgentTicketZoom
        $Helper->ConfigSettingChange(
            Valid => 1,
            Key   => 'Ticket::Frontend::ZoomCollectMeta',
            Value => 1
        );

        # set a filter to valid which has floater preview enabled
        $SysConfigObject->ConfigItemValidityUpdate(
            Name  => 'Ticket::Frontend::ZoomCollectMetaFilters###CVE-Mitre',
            Valid => 1,
        );

        my $Language      = 'de';
        my $TestUserLogin = $Helper->TestUserCreate(
            Language => $Language,
            Groups   => [ 'admin', 'users' ],
        ) || die "Did not get test user";

        # get test user ID
        my $TestUserID = $Kernel::OM->Get('Kernel::System::User')->UserLookup(
            UserLogin => $TestUserLogin,
        );

        # get ticket object
        my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

        # create test ticket
        my $TicketID = $TicketObject->TicketCreate(
            Title        => 'Selenium Ticket',
            Queue        => 'Raw',
            Lock         => 'unlock',
            Priority     => '3 normal',
            State        => 'new',
            CustomerID   => '123465',
            CustomerUser => 'customer@example.com',
            OwnerID      => 1,
            UserID       => 1,
        );
        $Self->True(
            $TicketID,
            "TicketCreate - ID $TicketID",
        );

        my @ArticleIDs;

        my $ArticleIDPlain = $TicketObject->ArticleCreate(
            TicketID    => $TicketID,
            ArticleType => 'note-internal',
            SenderType  => 'agent',
            Subject     => 'Selenium subject test',
            Body =>
                'This is a test with some CVE numbers in it. They CVE-353-22 should be recognized correctly and displayed next to the article body: CVE-353-19, CVE-353-13',
            ContentType    => 'text/plain; charset=ISO-8859-15',
            HistoryType    => 'OwnerUpdate',
            HistoryComment => 'Some free text!',
            UserID         => 1,
            NoAgentNotify  => 1,
        );

        $Self->True(
            $ArticleIDPlain,
            "ArticleCreate - ID $ArticleIDPlain",
        );

        push @ArticleIDs, $ArticleIDPlain;

        my $ArticleIDHTML = $TicketObject->ArticleCreate(
            TicketID    => $TicketID,
            ArticleType => 'note-internal',
            SenderType  => 'agent',
            Subject     => 'some short description',
            Body =>
                '<p>This is an HTML article containing some CVE-Numbers like <ul><li>CVE-353-19</li><li>CVE-353-13</li></ul></p>',
            ContentType    => 'text/html; charset=ISO-8859-15',
            HistoryType    => 'AddNote',
            HistoryComment => 'Some free text!',
            UserID         => $TestUserID,
        );

        $Self->True(
            $ArticleIDHTML,
            "ArticleCreate - ID $ArticleIDHTML",
        );

        push @ArticleIDs, $ArticleIDHTML;

        $Selenium->Login(
            Type     => 'Agent',
            User     => $TestUserLogin,
            Password => $TestUserLogin,
        );

        # get script alias
        my $ScriptAlias = $Kernel::OM->Get('Kernel::Config')->Get('ScriptAlias');

        for my $ArticleID (@ArticleIDs) {

            # navigate to AgentTicketZoom screen of created test ticket
            $Selenium->VerifiedGet(
                "${ScriptAlias}index.pl?Action=AgentTicketZoom;TicketID=$TicketID;ArticleID=$ArticleID"
            );

            # check if we are seeing the meta box
            $Selenium->find_element( ".ArticleMeta", "css" );

            # hover one of the meta elements
            $Selenium->execute_script("\$('.ArticleMeta').first().find('a:first-child').first().mouseenter();");

            # wait for the floater to be fully visible
            $Selenium->WaitFor(
                JavaScript =>
                    "return typeof(\$) === 'function' && parseInt(\$('.MetaFloater:visible').css('opacity'), 10) == 1"
            );

            # see if we have a floater visible now
            $Self->Is(
                $Selenium->execute_script("return \$('div.MetaFloater:visible').length"),
                1,
                'Floater is visible'
            );

            # wait for the close button to fade in
            $Selenium->WaitFor(
                JavaScript =>
                    "return typeof(\$) === 'function' && \$('.MetaFloater:visible a.Close:visible').length == 1"
            );

            # close the floater again
            $Selenium->execute_script("\$('.MetaFloater a.Close').click();");

            # wait until the floater is gone
            $Selenium->WaitFor(
                JavaScript =>
                    "return typeof(\$) === 'function' && parseInt(\$('.MetaFloater:visible').length, 10) == 1"
            );
        }
    }
);

1;
