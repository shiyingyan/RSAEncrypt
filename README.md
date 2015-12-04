# RSAEncrypt
Encryption and Decryption with RSA

以下步骤，总共生成7个文件。
  其中public_key.der 和 private_key.p12 这对公钥>私钥是给IOS用的,rsa_public_key.pem 和pkcs8_private_key.pem是给JAVA用的。
　它们的源都来自一个私钥：private_key.pem, 所以IOS端加密的数据，是可以被JAVA端解密的，反过来也一样。

openssl genrsa -out private_key.pem 1024

openssl req -new -key private_key.pem -out rsaCertReq.csr

openssl x509 -req -days 3650 -in rsaCertReq.csr -signkey private_key.pem -out rsaCert.crt

openssl x509 -outform der -in rsaCert.crt -out public_key.der　　　　　　　　　　　　　　　// Create public_key.der For IOS
 
openssl pkcs12 -export -out private_key.p12 -inkey private_key.pem -in rsaCert.crt　　// Create private_key.p12 For IOS. 这一步，请记住你输入的密码，IOS代码里会用到

openssl rsa -in private_key.pem -out rsa_public_key.pem -pubout　　　　　　　　　　　　　// Create rsa_public_key.pem For Java
　
openssl pkcs8 -topk8 -in private_key.pem -out pkcs8_private_key.pem -nocrypt　　　　　// Create pkcs8_private_key.pem For Java
