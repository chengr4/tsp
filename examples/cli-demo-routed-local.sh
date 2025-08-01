#!/bin/bash

# this scripts sends a routed message from a -> p -> q -> q2 -> b
# where p and q run using the intermediary server

# here the intermediaries also need to use the feature "use_local_certificate":
#
#    cargo run --features use_local_certificate --bin demo-intermediary -- --port 3011 localhost:3001
#    cargo run --features use_local_certificate --bin demo-intermediary -- --port 3012 localhost:3002
#
# (you should run these in separate terminals, together with the SSL proxy)

cargo install --path . --features use_local_certificate,pq

echo "---- cleanup the wallet"
rm -f a.sqlite b.sqlite

echo
echo "==== create sender and receiver"
for entity in a b; do
    echo "------ $entity (identifier for ${entity%%[0-9]*}) uses did:peer with local transport"
    port=$((${port:-1024} + RANDOM % 1000))
    tsp --wallet "${entity%%[0-9]*}" create --type peer --tcp localhost:$port $entity
done
DID_A=$(tsp --wallet a print a)
DID_P="did:web:localhost%3A3001"
DID_Q="did:web:localhost%3A3002"
DID_B=$(tsp --wallet b print b)

wait
sleep 2
echo
echo "==== let the nodes introduce each other"

echo "---- verify the address of the receiver"
tsp --wallet a verify --alias b "$DID_B"

echo "---- establish outer relation a<->p"
tsp --wallet a verify --alias p "$DID_P"
sleep 2 && tsp --wallet a request --wait -s a -r p

echo "---- establish outer relation q<->b"
tsp --wallet b verify --alias q "$DID_Q"
sleep 2 && tsp --wallet b request --wait -s b -r q

echo "---- establish nested outer relation q<->b" # required for drop-off
sleep 2 && read -d '' DID_B2 DID_Q2 <<< $(tsp --wallet b request --wait --nested -s b -r q)

echo "DID_B2=$DID_B2"
echo "DID_Q2=$DID_Q2"

echo "---- setup the route"
tsp --wallet a set-route b "p,$DID_Q,$DID_Q2"

wait
sleep 5
echo
echo "==== send a routed message"

sleep 2 && echo -n "Indirect Message from A to B via P and Q was received!" | tsp --wallet a send -s a -r b &
tsp --yes --wallet b receive --one b

echo "---- cleanup wallets"
rm -f a.sqlite b.sqlite
