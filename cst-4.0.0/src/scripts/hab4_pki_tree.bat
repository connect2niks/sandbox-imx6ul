@echo off

:: -----------------------------------------------------------------------------
::
:: File: hab4_pki_tree.bat
::
:: Description: This script generates a basic HAB4 PKI tree for the NXP
::              HAB code signing feature.  What the PKI tree looks like depends
::              on whether the SRK is chosen to be a CA key or not.  If the
::              SRKs are chosen to be CA keys then this script will generate the
::              following PKI tree:
::
::                                      CA Key
::                                      | | |
::                             -------- + | +---------------
::                            /           |                 \
::                         SRK1          SRK2       ...      SRKN
::                         / \            / \                / \
::                        /   \          /   \              /   \
::                   CSF1_1  IMG1_1  CSF2_1  IMG2_1 ... CSFN_1  IMGN_1
::
::              where: N can be 1 to 4.
::
::              Additional keys can be added to the tree separately.  In this
::              configuration SRKs may only be used to sign/verify other
::              keys/certificates
::
::              If the SRKs are chosen to be non-CA keys then this script will
::              generate the following PKI tree:
::
::                                      CA Key
::                                      | | |
::                             -------- + | +---------------
::                            /           |                 \
::                         SRK1          SRK2       ...      SRKN
::
::              In this configuration SRKs may only be used to sign code/data
::              and not other keys.  Note that not all Freescale processors
::              including HAB support this option.
::
::            (c) Freescale Semiconductor, Inc. 2011. All rights reserved.
::            Copyright 2018-2022 NXP
::
::
:: ----------------------------------------------------------------------------

echo.
echo     +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
echo     This script is a part of the Code signing tools for NXP's
echo     High Assurance Boot.  It generates a basic PKI tree.  The PKI
echo     tree consists of one or more Super Root Keys (SRK), with each
echo     SRK having two subordinate keys:
echo         + a Command Sequence File (CSF) key
echo         + Image key.
echo     Additional keys can be added to the PKI tree but a separate
echo     script is available for this.  This this script assumes openssl
echo     is installed on your system and is included in your search
echo     path.  Finally, the private keys generated are password
echo     protectedwith the password provided by the file key_pass.txt.
echo     The format of the file is the password repeated twice:
echo         my_password
echo         my_password
echo     All private keys in the PKI tree will be protected by the same
echo     password.
echo     +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
echo.

set scriptName=%0
set scriptPath=%~dp0
set numArgs=0
for %%x in (%*) do set /A numArgs+=1

if %numArgs% GTR 0 (
	set interactive=n
) else (
	set interactive=y
)

:: Initialize global variables
set max_param=16
set min_param=12

set args=0
set "existing_ca="
set "ca_key="
set "ca_cert="
set use_ecc=n
set use_rsa_pss=n
set "kl="
set "duration="
set "num_srk="
set "srk_ca="

if %interactive%==n (
	if "%1" == "-h" ( goto usage )
	if "%1" == "--help" ( goto usage )
) else (
	goto process_existing_ca
)

:: Validate command line parameters
if %numArgs% LSS %min_param% (
	echo ERROR: Correct parameters required in non-interactive mode
	goto usage
)
if %numArgs% GTR %max_param% (
	echo ERROR: Correct parameters required in non-interactive mode
	goto usage
)

:: Process command line inputs
:PROCESSINPUT
if %args% GEQ %numArgs% goto validateargs
if "%1"=="-existing-ca" (
	set existing_ca=%2
	goto shiftargs
)
if "%1"=="-ca-key" (
	set ca_key=%2
	goto shiftargs
)
if "%1"=="-ca-cert" (
	set ca_cert=%2
	goto shiftargs
)
if "%1"=="-kt" (
	set use_key_type=%2
	goto shiftargs
)
if "%1"=="-kl" (
	set kl=%2
	goto shiftargs
)
if "%1"=="-duration" (
	set duration=%2
	goto shiftargs
)
if "%1"=="-num-srk" (
	set num_srk=%2
	goto shiftargs
)
if "%1"=="-srk-ca" (
	set srk_ca=%2
	goto shiftargs
) else (
	echo ERROR: Invalid parameter: %1
    goto usage
)

:SHIFTARGS
shift
shift
set /A args+=2
goto processinput

:VALIDATEARGS
if %existing_ca%==y ( if not defined ca_key (
	echo ERROR: CA key is required.
	goto usage
))

if %existing_ca%==y ( if not defined ca_cert (
	echo ERROR: CA cert is required
	goto usage
))

goto process_existing_ca

:USAGE
echo Usage:
echo Interactive Mode:
echo %scriptName%
echo.
echo Command Line Mode:
echo "%scriptName% -existing-ca <y/n> [-ca-key <CA key name> -ca-cert <CA cert name>] -kt <rsa/rsa-pss/ecc> -kl <ECC/RSA Key Length> -duration <years> -num-srk <1-4> -srk-ca <y/n>"
echo Options:
echo     -kl ecc     : then Supported key lengths: p256, p384, p521
echo     -kl rsa     : then Supported key lengths: 1024, 2048, 3072, 4096
echo     -kl rsa-pss : then Supported key lengths: 1024, 2048, 3072, 4096
echo.
echo "%scriptName% -h | --help : This text"
echo.
exit /B

:PROCESS_EXISTING_CA
if %interactive%==y (
	set /P existing_ca="Do you want to use an existing CA key (y/n)?: "
)
if %existing_ca%==n goto KEY_TYPE_SELECT
if %interactive%==y (
	set /P ca_key="Enter CA key name: "
	set /P ca_cert="Enter CA certificate name: "
)

:KEY_TYPE_SELECT
:: This script defaults to the RSA key type. Switch to a different key type if selected.
if %interactive%==y (
  echo.
  echo "Key Type Options:"
	set /P use_key_type="Select the key type (possible values: rsa, rsa-pss, ecc)?: "
)
if %use_key_type%==ecc goto KEY_TYPE
if %use_key_type%==rsa-pss set use_rsa_pss=y & goto KEY_TYPE
if %use_key_type%==rsa set use_ecc=y & goto KEY_TYPE
echo Invalid key type selected
exit /B

:KEY_TYPE
if %use_ecc%==y goto KEY_LENGTH_ECC
if %use_rsa_pss%==y set rsa_algo=rsa-pss & goto KEY_LENGTH_RSA
:: Select the default RSA key type
set rsa_algo=rsa
goto KEY_LENGTH_RSA

:KEY_LENGTH_ECC
if %interactive%==y (
	echo Enter length for elliptic curve to be used for PKI tree:
	set /P kl="Possible values p256, p384, p521: "
)

:: Confirm that a valid key length has been entered
if %kl%==p256 (
   set cn="secp256r1"
   goto VALID_KEY_LENGTH
)
if %kl%==p384 (
   set cn="secp384r1"
   goto VALID_KEY_LENGTH
)
if %kl%==p521 (
   set cn="secp521r1"
   goto VALID_KEY_LENGTH
)
echo Invalid key length. Supported key lengths: 256, 384, 521
exit /B

:KEY_LENGTH_RSA
if %interactive%==y (
	set /P kl="Enter key length in bits for PKI tree: "
)
:: Confirm that a valid key length has been entered
if %kl%==1024 goto VALID_KEY_LENGTH
if %kl%==2048 goto VALID_KEY_LENGTH
if %kl%==3072 goto VALID_KEY_LENGTH
if %kl%==4096 goto VALID_KEY_LENGTH
echo Invalid key length. Supported key lengths: 1024, 2048, 3072, 4096
exit /B

:VALID_KEY_LENGTH
if %interactive%==y (
	set /P duration="Enter PKI tree duration (years): "
)
:: Compute validity period
set /A val_period=%duration%*365

if %interactive%==y (
	set /P num_srk="How many Super Root Keys should be generated? "
)

:: Check that 0 < num_srk < 4 (Max. number of SRKs)
if %num_srk%==1 goto VALID_NUM_KEYS
if %num_srk%==2 goto VALID_NUM_KEYS
if %num_srk%==3 goto VALID_NUM_KEYS
if %num_srk%==4 goto VALID_NUM_KEYS
echo The number of SRKs generated must be between 1 and 4
exit /B
:VALID_NUM_KEYS

if %interactive%==y (
	:: Check if SRKs should be generated as CA certs or user certs
	set /P srk_ca="Do you want the SRK certificates to have the CA flag set? (y/n)?: "
)

:BEFORE_GEN_KEYS
:: Check existance of keys/, crts/ and ca/ directories of <cst> before generating keys and
:: switch current working directory to <cst>/keys directory, if needed.
set crt_dir=%cd%
set keys_dir=%scriptPath%\\..\\keys\\
set crts_dir=%scriptPath%\\..\\crts\\
set ca_dir=%scriptPath%\\..\\ca\\

if not exist "%keys_dir%" (
    echo ERROR: Private keys directory %keys_dir% is missing. Expecting script to be located inside ^<cst^>/keys directory.
    exit /B
)

if not exist "%crts_dir%" (
    echo ERROR: Public keys directory %crts_dir% is missing. Expecting ^<cst^>/crts directory to be already created.
    exit /B
)

if not exist "%ca_dir%" (
    echo ERROR: Openssl configuration directory %ca_dir% is missing. Expecting ^<cst^>/ca directory to hold openssl configuration files.
    exit /B
)

:: Switch current working directory to <cst>/keys directory, if needed.
if not "%crt_dir%" == "%keys_dir%" (
    cd "%keys_dir%" 
    if %errorlevel% NEQ 0 (
        echo ERROR: Cannot change directory to %keys_dir%
        exit /B
    )
)

:SERIAL
:: Check that the file "serial" is present, if not create it:
if exist "serial" goto KEY_PASS
echo 12345678 > serial
echo A default 'serial' file was created!

:KEY_PASS
:: Check that the file "key_pass.txt" is present, if not create it with default user/pwd:
if exist "key_pass.txt" goto OPENSSL_INIT
echo test> key_pass.txt
echo test>> key_pass.txt
echo A default file 'key_pass.txt' was created with password = test!

:OPENSSL_INIT
:: Convert file in Unix format for OpenSSL 1.0.2
convlb key_pass.txt
:: The following is required otherwise OpenSSL complains
if exist index.txt      del /F index.txt
if exist index.txt.attr del /F index.txt.attr
type nul > index.txt
echo unique_subject = no > index.txt.attr
set OPENSSL_CONF=..\\ca\\openssl.cnf

if %existing_ca%==y goto GEN_SRK
:: Generate CA key and certificate
:: -------------------------------

echo.
echo +++++++++++++++++++++++++++++++++++++
echo + Generating CA key and certificate +
echo +++++++++++++++++++++++++++++++++++++
echo.
if %use_ecc%==y GOTO g1_ecc

	set ca_key=CA1_sha256_%kl%_65537_v3_ca_key
        set ca_cert=..\\crts\\CA1_sha256_%kl%_65537_v3_ca_crt
        set ca_subj_req=/CN=CA1_sha256_%kl%_65537_v3_ca/
        set ca_key_type=rsa:%kl%

goto g1_done
:g1_ecc
        set eck=ec-%cn%.pem
	openssl ecparam -out %eck% -name %cn%
	set ca_key=CA1_sha256_%cn%_v3_ca_key
        set ca_cert=..\\crts\\CA1_sha256_%cn%_v3_ca_crt
        set ca_subj_req=/CN=CA1_sha256_%cn%_v3_ca/
        set ca_key_type=ec:%eck%

:g1_done

:: Note: '^' is to continue the command on the next line
openssl req -newkey %ca_key_type% -passout file:key_pass.txt ^
    -subj %ca_subj_req% ^
    -x509 -extensions v3_ca ^
    -keyout temp_ca.pem ^
    -out %ca_cert%.pem ^
    -days %val_period%

:: Generate CA key in PKCS #8 format - both PEM and DER
openssl pkcs8 -passin file:key_pass.txt -passout file:key_pass.txt ^
    -topk8 -inform PEM -outform DER -v2 des3 ^
    -in temp_ca.pem ^
    -out %ca_key%.der

openssl pkcs8 -passin file:key_pass.txt -passout file:key_pass.txt ^
    -topk8 -inform PEM -outform PEM -v2 des3 ^
    -in temp_ca.pem ^
    -out %ca_key%.pem

:: Convert CA Certificate to DER format
openssl x509 -inform PEM -outform DER -in %ca_cert%.pem -out %ca_cert%.der

:: Cleanup
del /F temp_ca.pem

:GEN_SRK
if %srk_ca%==y goto GEN_SRK_CSF_IMG
:: Generate SRK keys and certificates (non-CA)
:: SRKs suitable for signing code/data
:: -------------------------------------------
set /a i=1
set /a max=num_srk+1

:GEN_SRK_LOOP
echo.
echo ++++++++++++++++++++++++++++++++++++++++
echo + Generating SRK key and certificate %i% +
echo ++++++++++++++++++++++++++++++++++++++++
echo.
if %use_ecc%==y GOTO g2_ecc

	:: Generate SRK key
	openssl genpkey -algorithm %rsa_algo% -pkeyopt rsa_keygen_bits:%kl% ^
                  -pass file:key_pass.txt ^
                  -out temp_srk.pem

	set srk_subj_req=/CN=SRK%i%_sha256_%kl%_65537_v3_usr/
	set srk_crt=..\\crts\\SRK%i%_sha256_%kl%_65537_v3_usr_crt
	set srk_key=SRK%i%_sha256_%kl%_65537_v3_usr_key
goto g2_done
:g2_ecc
        :: Generate Elliptic Curve parameters:
        openssl ecparam -out temp_srk.pem -name %cn% -genkey

	:: Generate SRK key
	openssl ec -in temp_srk.pem -des3 -passout file:key_pass.txt ^
	    -out temp_srk.pem

	set srk_subj_req=/CN=SRK%i%_sha256_%cn%_v3_usr/
	set srk_crt=..\\crts\\SRK%i%_sha256_%cn%_v3_usr_crt
	set srk_key=SRK%i%_sha256_%cn%_v3_usr_key

:g2_done


:: Generate SRK certificate signing request
openssl req -new -batch -passin file:key_pass.txt ^
    -subj %srk_subj_req% ^
    -key temp_srk.pem ^
    -out temp_srk_req.pem

:: Generate SRK certificate (this is a CA cert)
openssl ca -batch -passin file:key_pass.txt ^
    -md sha256 -outdir . ^
    -in temp_srk_req.pem ^
    -cert %ca_cert%.pem ^
    -keyfile %ca_key%.pem ^
    -extfile ..\\ca\\v3_usr.cnf ^
    -out %srk_crt%.pem ^
    -days %val_period%

::Convert SRK Certificate to DER format
openssl x509 -inform PEM -outform DER ^
    -in %srk_crt%.pem ^
    -out %srk_crt%.der

:: Generate CA key in PKCS #8 format - both PEM and DER
openssl pkcs8 -passin file:key_pass.txt -passout file:key_pass.txt ^
    -topk8 -inform PEM -outform DER -v2 des3 ^
    -in temp_srk.pem ^
    -out %srk_key%.der

openssl pkcs8 -passin file:key_pass.txt -passout file:key_pass.txt ^
    -topk8 -inform PEM -outform PEM -v2 des3 ^
    -in temp_srk.pem ^
    -out %srk_key%.pem

:: Cleanup
del /F temp_srk.pem temp_srk_req.pem

set /a i += 1
if %i%==%max% goto DONE
goto GEN_SRK_LOOP

:: Generate HAB keys and certificate
:: ---------------------------------
:GEN_SRK_CSF_IMG
set /a i=1
set /a max=num_srk+1

:GEN_SRK_CSF_IMG_LOOP
echo.
echo ++++++++++++++++++++++++++++++++++++++++
echo + Generating SRK key and certificate %i% +
echo ++++++++++++++++++++++++++++++++++++++++
echo.
if %use_ecc%==y GOTO g3_ecc

	:: Generate SRK key
	openssl genpkey -algorithm %rsa_algo% -pkeyopt rsa_keygen_bits:%kl% ^
                  -pass file:key_pass.txt ^
                  -out temp_srk.pem

	set srk_subj_req=/CN=SRK%i%_sha256_%kl%_65537_v3_ca/
	set srk_crt=..\\crts\\SRK%i%_sha256_%kl%_65537_v3_ca_crt
	set srk_key=SRK%i%_sha256_%kl%_65537_v3_ca_key

goto g3_done
:g3_ecc
        :: Generate Elliptic Curve parameters:
        openssl ecparam -out temp_srk.pem -name %cn% -genkey

	:: Generate SRK key
	openssl ec -in temp_srk.pem -des3 -passout file:key_pass.txt ^
	    -out temp_srk.pem

	set srk_subj_req=/CN=SRK%i%_sha256_%cn%_v3_ca/
	set srk_crt=..\\crts\\SRK%i%_sha256_%cn%_v3_ca_crt
	set srk_key=SRK%i%_sha256_%cn%_v3_ca_key
:g3_done

:: Generate SRK certificate signing request
openssl req -new -batch -passin file:key_pass.txt ^
    -subj %srk_subj_req% ^
    -key temp_srk.pem ^
    -out temp_srk_req.pem

:: Generate SRK certificate (this is a CA cert)
openssl ca -batch -passin file:key_pass.txt ^
    -md sha256 -outdir . ^
    -in temp_srk_req.pem ^
    -cert %ca_cert%.pem ^
    -keyfile %ca_key%.pem ^
    -extfile ..\\ca\\v3_ca.cnf ^
    -out %srk_crt%.pem ^
    -days %val_period%

::Convert SRK Certificate to DER format
openssl x509 -inform PEM -outform DER ^
    -in %srk_crt%.pem ^
    -out %srk_crt%.der

:: Generate CA key in PKCS #8 format - both PEM and DER
openssl pkcs8 -passin file:key_pass.txt -passout file:key_pass.txt ^
    -topk8 -inform PEM -outform DER -v2 des3 ^
    -in temp_srk.pem ^
    -out %srk_key%.der

openssl pkcs8 -passin file:key_pass.txt -passout file:key_pass.txt ^
    -topk8 -inform PEM -outform PEM -v2 des3 ^
    -in temp_srk.pem ^
    -out %srk_key%.pem

:: Cleanup
del /F temp_srk.pem temp_srk_req.pem

echo.
echo ++++++++++++++++++++++++++++++++++++++++
echo + Generating CSF key and certificate %i% +
echo ++++++++++++++++++++++++++++++++++++++++
echo.
if %use_ecc%==y goto g4_ecc
	set srk_crt_i=..\\crts\\SRK%i%_sha256_%kl%_65537_v3_ca_crt.pem
        set srk_key_i=SRK%i%_sha256_%kl%_65537_v3_ca_key.pem
	:: Generate key
	openssl genpkey -algorithm %rsa_algo% -pkeyopt rsa_keygen_bits:%kl% ^
                  -pass file:key_pass.txt ^
                  -out temp_csf.pem

        set csf_subj_req=/CN=CSF%i%_1_sha256_%kl%_65537_v3_usr/
        set csf_crt=..\\crts\\CSF%i%_1_sha256_%kl%_65537_v3_usr_crt
        set csf_key=CSF%i%_1_sha256_%kl%_65537_v3_usr_key

goto g4_done
:g4_ecc
	set srk_crt_i=..\\crts\\SRK%i%_sha256_%cn%_v3_ca_crt.pem
        set srk_key_i=SRK%i%_sha256_%cn%_v3_ca_key.pem
        :: Generate Elliptic Curve parameters:
        openssl ecparam -out temp_csf.pem -name %cn% -genkey

	:: Generate key
	openssl ec -in temp_csf.pem -des3 -passout file:key_pass.txt ^
	    -out temp_csf.pem

        set csf_subj_req=/CN=CSF%i%_1_sha256_%cn%_v3_usr/
        set csf_crt=..\\crts\\CSF%i%_1_sha256_%cn%_v3_usr_crt
        set csf_key=CSF%i%_1_sha256_%cn%_v3_usr_key
:g4_done


:: Generate CSF certificate signing request
openssl req -new -batch -passin file:key_pass.txt ^
    -subj %csf_subj_req% ^
    -key temp_csf.pem ^
    -out temp_csf_req.pem

:: Generate CSF certificate (this is a user cert)
openssl ca -batch -md sha256 -outdir . ^
    -passin file:key_pass.txt ^
    -in temp_csf_req.pem ^
    -cert %srk_crt_i% ^
    -keyfile %srk_key_i% ^
    -extfile ..\\ca\\v3_usr.cnf ^
    -out %csf_crt%.pem ^
    -days %val_period%

::Convert CSF Certificate to DER format
openssl x509 -inform PEM -outform DER ^
    -in %csf_crt%.pem ^
    -out %csf_crt%.der

:: Generate CA key in PKCS #8 format - both PEM and DER
openssl pkcs8 -passin file:key_pass.txt -passout file:key_pass.txt ^
    -topk8 -inform PEM -outform PEM -v2 des3 ^
    -in temp_csf.pem ^
    -out %csf_key%.der

openssl pkcs8 -passin file:key_pass.txt -passout file:key_pass.txt ^
    -topk8 -inform PEM -outform PEM -v2 des3 ^
    -in temp_csf.pem ^
    -out %csf_key%.pem


:: Cleanup
del /F temp_csf.pem temp_csf_req.pem

echo.
echo ++++++++++++++++++++++++++++++++++++++++
echo + Generating IMG key and certificate %i% +
echo ++++++++++++++++++++++++++++++++++++++++
echo.

if %use_ecc%==y goto g5_ecc
	:: Generate key
	openssl genpkey -algorithm %rsa_algo% -pkeyopt rsa_keygen_bits:%kl% ^
                  -pass file:key_pass.txt ^
                  -out temp_img.pem

        set img_subj_req=/CN=IMG%i%_1_sha256_%kl%_65537_v3_usr/
        set img_crt=..\\crts\\IMG%i%_1_sha256_%kl%_65537_v3_usr_crt
        set img_key=IMG%i%_1_sha256_%kl%_65537_v3_usr_key
goto g5_done
:g5_ecc
        :: Generate Elliptic Curve parameters:
        openssl ecparam -out temp_img.pem -name %cn% -genkey

	:: Generate key
	openssl ec -in temp_img.pem -des3 -passout file:key_pass.txt ^
	    -out temp_img.pem

        set img_subj_req=/CN=IMG%i%_1_sha256_%cn%_v3_usr/
        set img_crt=..\\crts\\IMG%i%_1_sha256_%cn%_v3_usr_crt
        set img_key=IMG%i%_1_sha256_%cn%_v3_usr_key
:g5_done

:: Generate IMG certificate signing request
openssl req -new -batch -passin file:key_pass.txt ^
    -subj %img_subj_req% ^
    -key temp_img.pem ^
    -out temp_img_req.pem

openssl ca -batch -md sha256 -outdir . ^
    -passin file:key_pass.txt ^
    -in temp_img_req.pem ^
    -cert %srk_crt_i% ^
    -keyfile %srk_key_i% ^
    -extfile ..\\ca\\v3_usr.cnf ^
    -out %img_crt%.pem ^
    -days %val_period%

:: Convert SRK Certificate to DER format
openssl x509 -inform PEM -outform DER ^
    -in %img_crt%.pem ^
    -out %img_crt%.der

:: Generate CA key in PKCS #8 format - both PEM and DER
openssl pkcs8 -passin file:key_pass.txt -passout file:key_pass.txt ^
    -topk8 -inform PEM -outform DER -v2 des3 ^
    -in temp_img.pem ^
    -out %img_key%.der

openssl pkcs8 -passin file:key_pass.txt -passout file:key_pass.txt ^
    -topk8 -inform PEM -outform PEM -v2 des3 ^
    -in temp_img.pem ^
    -out %img_key%.pem

:: Cleanup
del /F temp_img.pem temp_img_req.pem

set /a i += 1
if %i%==%max% goto DONE
goto GEN_SRK_CSF_IMG_LOOP

:DONE
:: Switch back to initial working directory, if needed.
if not "%crt_dir%" == "%keys_dir%" (
    cd "%crt_dir%" 
    if %errorlevel% NEQ 0 (
        echo ERROR: Cannot change directory to %crt_dir%
        exit /B
    )
)
exit /B
