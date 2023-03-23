import { StreamClient, v1alpha2 } from "@apibara/protocol";
import {
  Filter,
  FieldElement,
  v1alpha2 as starknet,
  StarkNetCursor,
} from "@apibara/starknet";
import { PrismaClient } from "@prisma/client";
import domainResolvers from "../hooks/domain.resolvers";
import { hash, number } from "starknet";

const db = new PrismaClient();
const { convertDomainHashToHumanReadable } = domainResolvers();

// Grab Apibara DNA token from environment, if any.
const AUTH_TOKEN = "dna_uO1K4NpIUzXJxFNUVxSk";

const REGISTERER_CONTRACT = FieldElement.fromBigInt(
  "0x564742bd75538e017a0ba7f23c9b6746d956458ce76e9d00e9182ba0b934acd"
);

const DOMAIN_REGISTERED_BN = BigInt(
  hash.getSelectorFromName("new_domain_registered")
);
const DOMAIN_REGISTERED_KEY = FieldElement.fromBigInt(DOMAIN_REGISTERED_BN);

const DOMAIN_UPDATED_BN = BigInt(hash.getSelectorFromName("domain_updated"));
const DOMAIN_UPDATED_KEY = FieldElement.fromBigInt(DOMAIN_UPDATED_BN);

const DOMAIN_RENEWED_BN = BigInt(hash.getSelectorFromName("domain_renewed"));
const DOMAIN_RENEWED_KEY = FieldElement.fromBigInt(DOMAIN_RENEWED_BN);

function baseFilter() {
  const main_filter = Filter.create();
  main_filter
    .withHeader()
    .addEvent((ev) =>
      ev.withFromAddress(REGISTERER_CONTRACT).withKeys([DOMAIN_REGISTERED_KEY])
    );
  main_filter
    .withHeader()
    .addEvent((ev) =>
      ev.withFromAddress(REGISTERER_CONTRACT).withKeys([DOMAIN_UPDATED_KEY])
    );
  main_filter
    .withHeader()
    .addEvent((ev) =>
      ev.withFromAddress(REGISTERER_CONTRACT).withKeys([DOMAIN_RENEWED_KEY])
    );
  return main_filter;
}

function baseFilter_domain_update() {
  return Filter.create()
    .withHeader()
    .addEvent((ev) =>
      ev.withFromAddress(REGISTERER_CONTRACT).withKeys([DOMAIN_UPDATED_KEY])
    );
}

async function handleBatch(
  client: StreamClient,
  cursor: v1alpha2.ICursor | null,
  batch: Uint8Array[]
) {
  for (let item of batch) {
    const block = starknet.Block.decode(item);
    for (let { transaction, event } of block.events) {
      if (
        !event ||
        !event.keys ||
        !event.data ||
        !transaction?.meta?.hash ||
        !event.fromAddress
      ) {
        continue;
      }
      const blockNumber = block.header?.blockNumber;
      console.log(`blockNumber`, blockNumber);
      const txHash = FieldElement.toHex(transaction.meta.hash);

      const key = FieldElement.toBigInt(event.keys[0]);
      if (key == DOMAIN_REGISTERED_BN) {
        let event_obj = {
          token_id: FieldElement.toBigInt(event.data[0]).toString(),
          domain: FieldElement.toBigInt(event.data[2]).toString(),
          resolved_domain: convertDomainHashToHumanReadable(
            FieldElement.toBigInt(event.data[2]).toString()
          ),
          resolver_address: number.cleanHex(FieldElement.toHex(event.data[3])),
          expire_date: FieldElement.toBigInt(event.data[4]).toString(),
          avatar_hash: FieldElement.toBigInt(event.data[6]).toString(),
        };

        try {
          await db.domains.upsert({
            where: {
              domain: event_obj.domain,
            },
            create: event_obj,
            update: {
              token_id: event_obj.token_id,
              resolver_address: event_obj.resolver_address,
              resolved_domain: convertDomainHashToHumanReadable(
                String(event_obj.domain)
              ),
              expire_date: event_obj.expire_date,
              avatar_hash: event_obj.avatar_hash,
            },
          });
          await db.profile_info.upsert({
            where: {
              profile_domain_uuid: event_obj.domain,
            },
            create: {
              profile_domain_uuid: event_obj.domain,
              is_inited: true,
            },
            update: {
              is_inited: true,
            },
          });
          console.log("Identity Registered ✨");
          console.log("   Block number@", blockNumber, ", Txn hash@", txHash);
          console.log("   Identity Details", event_obj);
        } catch (error) {
          console.log(error, "error message");
        }
      } else if (key == DOMAIN_UPDATED_BN) {
        let event_obj = {
          token_id: FieldElement.toBigInt(event.data[0]).toString(),
          domain: FieldElement.toBigInt(event.data[2]).toString(),
          old_owner: number.cleanHex(FieldElement.toHex(event.data[3])),
          new_owner: number.cleanHex(FieldElement.toHex(event.data[4])),
          emitted_at: FieldElement.toBigInt(event.data[5]).toString(),
        };
        try {
          await db.domains.update({
            where: {
              token_id: event_obj.token_id,
            },
            data: {
              token_id: event_obj.token_id,
              domain: event_obj.domain,
              resolved_domain: convertDomainHashToHumanReadable(
                String(event_obj.domain)
              ),
              resolver_address: event_obj.new_owner,
              expire_date: undefined,
            },
          });
          console.log("Identity Updated ✨");
          console.log("   Block number@", blockNumber, ", Txn hash@", txHash);
          console.log("   Identity Update Details", event_obj);
        } catch (error) {
          console.log(error, "error message");
          console.log(
            "Tried to update, domain was => ",
            convertDomainHashToHumanReadable(String(event_obj.domain))
          );
        }
      } else if (key == DOMAIN_RENEWED_BN) {
        let event_obj = {
          token_id: FieldElement.toBigInt(event.data[0]).toString(),
          domain: FieldElement.toBigInt(event.data[2]).toString(),
          resolver: number.cleanHex(FieldElement.toHex(event.data[3])),
          resolved_domain: convertDomainHashToHumanReadable(
            FieldElement.toBigInt(event.data[2]).toString()
          ),
          expire_date: FieldElement.toBigInt(event.data[4]).toString(),
          emitted_at: FieldElement.toBigInt(event.data[5]).toString(),
          avatar_hash: FieldElement.toBigInt(event.data[6]).toString(),
        };

        try {
          await db.domains.update({
            where: {
              token_id: event_obj.token_id,
            },
            data: {
              token_id: event_obj.token_id,
              domain: event_obj.domain,
              resolved_domain: convertDomainHashToHumanReadable(
                event_obj.domain
              ),
              resolver_address: event_obj.resolver,
              expire_date: event_obj.expire_date,
              avatar_hash: event_obj.avatar_hash,
            },
          });
          console.log("Identity Renewed ✨");
          console.log("   Block number@", blockNumber, ", Txn hash@", txHash);
          console.log("   Identity Renewing Details", event_obj);
        } catch (error) {
          console.log(error, "error message");
          console.log(
            "Tried to renew, domain was",
            convertDomainHashToHumanReadable(event_obj.domain)
          );
        }
      }
    }
  }

  /// @dev we change the configuration of filter as follows
  // if (state == 1) {
  //   const filter = baseFilter_domain_update();

  //    client.configure({ filter: filter.encode(), cursor });
  // }
}

async function main() {
  console.log("Streaming Starknet Social 💫");

  const filter = baseFilter().encode();

  const client = new StreamClient({
    url: "goerli.starknet.a5a.ch:443",
    token: AUTH_TOKEN,
    clientOptions: {
      "grpc.max_receive_message_length": 128 * 1_048_576, // 128 MiB
    },
  });

  console.log("Batch size configured as 1");
  console.log("Finality setted as PENDING");
  // force use of batches with size 1 so that reconfiguring doesn't skip any block
  console.log("Connecting to apibara...");

  const cursor = StarkNetCursor.createWithBlockNumber(
    process.env.INDEXER_STARTING_BLOCK!
  );

  client.configure({
    filter,
    batchSize: 1,
    finality: v1alpha2.DataFinality.DATA_STATUS_UNKNOWN,
    cursor,
  });

  for await (const message of client) {
    if (message.data && message.data?.data) {
      handleBatch(client, message.data.endCursor, message.data.data);
    }
  }
}

main()
  .then(() => process.exit(0))
  .catch(console.error);
