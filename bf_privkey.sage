import hashlib
from ripemd.ripemd160 import ripemd160
import base58
p = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F
a = 0
b = 7
Gx = 0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798
Gy = 0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8

F = FiniteField(p)
E = EllipticCurve(F, [a, b])
G = E(Gx, Gy)

def format_public_key(P):
    return '04' + format(int(P[0]), '064x') + format(int(P[1]), '064x')

def private_key_to_wif(private_key_int):
    private_key_hex = format(private_key_int, '064x')
    version_byte = 'ef'
    extended_key_hex = version_byte + private_key_hex
    extended_key_bytes = bytes.fromhex(extended_key_hex)
    hash1 = hashlib.sha256(extended_key_bytes).digest()
    hash2 = hashlib.sha256(hash1).digest()
    checksum = hash2[:4]
    final_key_bytes = extended_key_bytes + checksum
    wif = base58.b58encode(final_key_bytes)
    return wif.decode('utf-8')

target_address = "muPctfb9rU8Pk2zYijEJZ4ohQLSoh5ikPF"
target_public_key_hash = bytes.fromhex("982ea6f8aaebca7355035fc7245cd0a314c8d54d")

max_key = 2**32
initial_private = 2000000
public_key = (initial_private-1) * G
for k in range(initial_private, max_key):
    if k % 10000 == 0:
        print(k)
    public_key = public_key + G
    public_key_hash = ripemd160(hashlib.sha256(bytes.fromhex(format_public_key(public_key))).digest())
    
    if public_key_hash == target_public_key_hash:
        print(k)
        print(private_key_to_wif(k))
        exit()