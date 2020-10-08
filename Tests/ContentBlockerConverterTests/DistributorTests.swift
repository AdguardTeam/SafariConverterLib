import Foundation

import XCTest
@testable import ContentBlockerConverter

final class DistributorTests: XCTestCase {
    func testEmpty() {
        let builder = Distributor(limit: 0, advancedBlocking: true);
        
        let result = try! builder.createConversionResult(data: CompilationResult());
        
        XCTAssertNotNil(result);
        XCTAssertEqual(result.totalConvertedCount, 0);
        XCTAssertEqual(result.convertedCount, 0);
        XCTAssertEqual(result.errorsCount, 0);
        XCTAssertEqual(result.overLimit, false);
        XCTAssertEqual(result.converted, "[\n\n]");
    }
    
    func testApplyWildcards() {
        
        let builder = Distributor(limit: 0, advancedBlocking: true);
        
        let testTrigger = BlockerEntry.Trigger(
            ifDomain: ["test_if_domain", "*wildcarded_if_domain"],
            urlFilter: "test_url_filter",
            unlessDomain: ["*test_unless_domain"],
            shortcut: "test_shorcut",
            regex: nil
        );
        
        let testAction = BlockerEntry.Action(
            type: "test_type",
            selector: nil,
            css: "test_css",
            script: nil,
            scriptlet: nil,
            scriptletParam: nil
        );
        
        var entries = [
            BlockerEntry(trigger: testTrigger, action: testAction)
        ];
        
        entries = builder.updateDomains(entries: entries);
        
        XCTAssertEqual(entries[0].trigger.ifDomain![0], "*test_if_domain");
        XCTAssertEqual(entries[0].trigger.ifDomain![1], "*wildcarded_if_domain");
        
        XCTAssertEqual(entries[0].trigger.unlessDomain![0], "*test_unless_domain");
    }

    private func parseJsonString(json: String) throws -> [BlockerEntry] {
        let data = json.data(using: String.Encoding.utf8, allowLossyConversion: false)!

        let decoder = JSONDecoder();
        let parsedData = try decoder.decode([BlockerEntry].self, from: data);

        return parsedData;
    }

    let converter = ContentBlockerConverter();

    func testHandleMaxDomainsForCssBlockingRules() {
        let builder = Distributor(limit: 0, advancedBlocking: true);
        let rule = "10daily.com.au,2gofm.com.au,923thefox.com,abajournal.com,abovethelaw.com,adn.com,advosports.com,adyou.me,androidfirmwares.net,aroundosceola.com,autoaction.com.au,autos.ca,autotrader.ca,ballstatedaily.com,baydriver.co.nz,bellinghamherald.com,bestproducts.com,birdmanstunna.com,blitzcorner.com,bnd.com,bradenton.com,browardpalmbeach.com,cantbeunseen.com,carynews.com,centredaily.com,chairmanlol.com,citymetric.com,citypages.com,claytonnewsstar.com,clicktogive.com,clinicaltrialsarena.com,coastandcountrynews.co.nz,cokeandpopcorn.com,commercialappeal.com,cosmopolitan.co.uk,cosmopolitan.com,cosmopolitan.in,cosmopolitan.ng,courierpress.com,cprogramming.com,dailynews.co.zw,dallasobserver.com,digitalspy.com,directupload.net,dispatch.com,diyfail.com,docspot.com,donchavez.com,driving.ca,dummies.com,edmunds.com,electrek.co,elledecor.com,energyvoice.com,enquirerherald.com,esquire.com,explainthisimage.com,expressandstar.com,film.com,foodista.com,fortmilltimes.com,forums.thefashionspot.com,fox.com.au,fox1150.com,fresnobee.com,funnyexam.com,funnytipjars.com,galatta.com,gamesindustry.biz,gamesville.com,geek.com,givememore.com.au,gmanetwork.com,goldenpages.be,goldfm.com.au,goodhousekeeping.com,gosanangelo.com,guernseypress.com,hardware.info,heart1073.com.au,heraldonline.com,hi-mag.com,hit105.com.au,hit107.com,hot1035.com,hot1035radio.com,hotfm.com.au,hourdetroit.com,housebeautiful.com,houstonpress.com,hypegames.com,iamdisappoint.com,idahostatesman.com,idello.org,imedicalapps.com,independentmail.com,indie1031.com,intomobile.com,ioljobs.co.za,irishexaminer.com,islandpacket.com,itnews.com.au,japanisweird.com,jerseyeveningpost.com,kentucky.com,keysnet.com,kidspot.com.au,kitsapsun.com,knoxnews.com,kofm.com.au,lakewyliepilot.com,laweekly.com,ledger-enquirer.com,legion.org,lgbtqnation.com,lifezette.com,lolhome.com,lonelyplanet.com,lsjournal.com,mac-forums.com,macon.com,mapcarta.com,marieclaire.co.za,marieclaire.com,marinmagazine.com,mcclatchydc.com,medicalnewstoday.com,mercedsunstar.com,meteovista.co.uk,meteovista.com,miaminewtimes.com,milesplit.com,mix.com.au,modbee.com,monocle.com,morefailat11.com,myrtlebeachonline.com,nameberry.com,naplesnews.com,nature.com,nbl.com.au,newarkrbp.org,newsobserver.com,newstatesman.com,nowtoronto.com,nxfm.com.au,objectiface.com,onnradio.com,openfile.ca,organizedwisdom.com,overclockers.com,passedoutphotos.com,pehub.com,peoplespharmacy.com,perfectlytimedphotos.com,phoenixnewtimes.com,photographyblog.com,pinknews.co,pons.com,pons.eu,radiowest.com.au,readamericanfootball.com,readarsenal.com,readastonvilla.com,readbasketball.com,readbetting.com,readbournemouth.com,readboxing.com,readbrighton.com,readbundesliga.com,readburnley.com,readcars.co,readceltic.com,readchampionship.com,readchelsea.com,readcricket.com,readcrystalpalace.com,readeverton.com,readeverything.co,readfashion.co,readfilm.co,readfood.co,readfootball.co,readgaming.co,readgolf.com,readhorseracing.com,readhuddersfield.com,readhull.com,readinternationalfootball.com,readlaliga.com,readleicester.com,readliverpoolfc.com,readmancity.com,readmanutd.com,readmiddlesbrough.com,readmma.com,readmotorsport.com,readmusic.co,readnewcastle.com,readnorwich.com,readnottinghamforest.com,readolympics.com,readpl.com,readrangers.com,readrugbyunion.com,readseriea.com,readshowbiz.co,readsouthampton.com,readsport.co,readstoke.com,readsunderland.com,readswansea.com,readtech.co,readtennis.co,readtottenham.com,readtv.co,readussoccer.com,readwatford.com,readwestbrom.com,readwestham.com,readwsl.com,rebubbled.com,recode.net,redding.com,reporternews.com,roadandtrack.com,roadrunner.com,roulettereactions.com,rr.com,sacarfan.co.za,sanluisobispo.com,scifinow.co.uk,seafm.com.au,searchenginesuggestions.com,shinyshiny.tv,shitbrix.com,shocktillyoudrop.com,shropshirestar.com,slashdot.org,slideshare.net,southerncrossten.com.au,space.com,spacecast.com,sparesomelol.com,spoiledphotos.com,sportsnet.ca,sportsvite.com,starfm.com.au,stopdroplol.com,straitstimes.com,stripes.com,stv.tv,sunfm.com.au,sunherald.com,supersport.com,tattoofailure.com,tbreak.com,tcpalm.com,techdigest.tv,techzim.co.zw,terra.com,theatermania.com,thecrimson.com,thejewishnews.com,thenewstribune.com,theolympian.com,therangecountry.com.au,theriver.com.au,theskanner.com,thestar.com.my,thestate.com,timescolonist.com,timesrecordnews.com,titantv.com,treehugger.com,tri-cityherald.com,triplem.com.au,triplemclassicrock.com,tutorialrepublic.com,tvfanatic.com,uswitch.com,vcstar.com,villagevoice.com,vivastreet.co.uk,walyou.com,waterline.co.nz,westword.com,where.ca,wired.com,wmagazine.com,yodawgpics.com,yoimaletyoufinish.com##.ads-block";
        let convertedRule = converter.convertArray(rules: [rule]);

        let decoded = try! parseJsonString(json: convertedRule!.converted);
        let entries: [BlockerEntry]  = [BlockerEntry(trigger: decoded[0].trigger, action: decoded[0].action)];
        let result = builder.updateDomains(entries: entries);
        XCTAssertNotNil(result);
        XCTAssertEqual(result.count, 1); // ToDO: Must be 2
        XCTAssertEqual(result[0].trigger.ifDomain!.count, 250);
    }


    static var allTests = [
        ("testEmpty", testEmpty),
        ("testApplyWildcards", testApplyWildcards),
        ("testHandleMaxDomainsForCssBlockingRules", testHandleMaxDomainsForCssBlockingRules),
    ]
}

