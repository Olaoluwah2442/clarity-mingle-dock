import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Can create an event",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('mingle-dock', 'create-event', [
        types.ascii("Tech Meetup 2024"),
        types.ascii("A gathering of tech enthusiasts"),
        types.ascii("Technology"),
        types.uint(1704067200), // Jan 1, 2024
        types.uint(100),
        types.uint(10000000) // 10 STX deposit
      ], deployer.address)
    ]);
    
    block.receipts[0].result.expectOk();
    assertEquals(block.receipts[0].result, types.ok(types.uint(1)));
  }
});

Clarinet.test({
  name: "Can RSVP to event and check in",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const participant = accounts.get('wallet_1')!;
    
    // Create event
    let block1 = chain.mineBlock([
      Tx.contractCall('mingle-dock', 'create-event', [
        types.ascii("Tech Meetup 2024"),
        types.ascii("A gathering of tech enthusiasts"),
        types.ascii("Technology"),
        types.uint(1704067200),
        types.uint(100),
        types.uint(10000000)
      ], deployer.address)
    ]);
    
    // RSVP to event
    let block2 = chain.mineBlock([
      Tx.contractCall('mingle-dock', 'rsvp', [
        types.uint(1)
      ], participant.address)
    ]);
    
    // Check in attendee
    let block3 = chain.mineBlock([
      Tx.contractCall('mingle-dock', 'check-in-attendee', [
        types.uint(1),
        types.principal(participant.address)
      ], deployer.address)
    ]);
    
    block2.receipts[0].result.expectOk();
    block3.receipts[0].result.expectOk();
    
    // Verify RSVP status
    let block4 = chain.mineBlock([
      Tx.contractCall('mingle-dock', 'get-rsvp-status', [
        types.uint(1),
        types.principal(participant.address)
      ], deployer.address)
    ]);
    
    const rsvpStatus = block4.receipts[0].result.expectOk().expectSome();
    assertEquals(rsvpStatus['checked-in'], types.bool(true));
  }
});

Clarinet.test({
  name: "Only event creator can cancel event",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const other = accounts.get('wallet_1')!;
    
    // Create event
    let block1 = chain.mineBlock([
      Tx.contractCall('mingle-dock', 'create-event', [
        types.ascii("Tech Meetup 2024"),
        types.ascii("A gathering of tech enthusiasts"),
        types.ascii("Technology"),
        types.uint(1704067200),
        types.uint(100),
        types.uint(10000000)
      ], deployer.address)
    ]);
    
    // Try to cancel event with non-creator
    let block2 = chain.mineBlock([
      Tx.contractCall('mingle-dock', 'cancel-event', [
        types.uint(1)
      ], other.address)
    ]);
    
    block2.receipts[0].result.expectErr(types.uint(104)); // err-unauthorized
  }
});