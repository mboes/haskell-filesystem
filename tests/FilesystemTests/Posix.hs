{-# LANGUAGE CPP #-}
{-# LANGUAGE ForeignFunctionInterface #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}

-- Copyright (C) 2011 John Millikin <jmillikin@gmail.com>
--
-- See license.txt for details
module FilesystemTests.Posix
	( test_Posix
	) where

import           Prelude hiding (FilePath)
import           Control.Monad
import           Control.Monad.IO.Class (liftIO)
import qualified Data.ByteString
import           Data.ByteString (ByteString)
import           Data.Text (Text)
import           Data.Time.Clock (diffUTCTime, getCurrentTime)
import           Foreign
import           Foreign.C
import           Test.Chell

#if MIN_VERSION_base(4,2,0)
import qualified GHC.IO.Exception as GHC
#else
import qualified GHC.IOBase as GHC
#endif

import           Filesystem
import           Filesystem.Path
import qualified Filesystem.Path.Rules as Rules
import qualified Filesystem.Path.CurrentOS as CurrentOS

import           FilesystemTests.Util (assertionsWithTemp, todo)

test_Posix :: Suite
test_Posix = suite "posix"
	[ suite "isFile"
		[ test_IsFile "ascii"
			(decode "test.txt")
		, test_IsFile "utf8"
			(fromText "\xA1\xA2.txt")
		, test_IsFile "iso8859"
			(decode "\xA1\xA2\xA3.txt")
		]
	, suite "isDirectory"
		[ test_IsDirectory "ascii"
			(decode "test.d")
		, test_IsDirectory "utf8"
			(fromText "\xA1\xA2.d")
		, test_IsDirectory "iso8859"
			(decode "\xA1\xA2\xA3.d")
		]
	, suite "rename"
		[ test_Rename "ascii"
			(decode "old_test.txt")
			(decode "new_test.txt")
		, test_Rename "utf8"
			(fromText "old_\xA1\xA2.txt")
			(fromText "new_\xA1\xA2.txt")
		, test_Rename "iso8859"
			(decode "old_\xA1\xA2\xA3.txt")
			(decode "new_\xA1\xA2\xA3.txt")
		]
	, suite "canonicalizePath"
		[ test_CanonicalizePath "ascii"
			(decode "test-a.txt")
			(decode "test-b.txt")
		, test_CanonicalizePath "utf8"
			(fromText "\xA1\xA2-a.txt")
			(fromText "\xA1\xA2-b.txt")
		, test_CanonicalizePath "iso8859"
			(decode "\xA1\xA2\xA3-a.txt")
			(decode "\xA1\xA2\xA3-b.txt")
		]
	, suite "createDirectory"
		[ test_CreateDirectory "ascii"
			(decode "test.d")
		, test_CreateDirectory "utf8"
			(fromText "\xA1\xA2.d")
		, test_CreateDirectory "iso8859"
			(decode "\xA1\xA2\xA3.d")
		, test_CreateDirectory_FailExists
		, test_CreateDirectory_SucceedExists
		, test_CreateDirectory_FailFileExists
		]
	, suite "createTree"
		[ test_CreateTree "ascii"
			(decode "test.d")
		, test_CreateTree "utf8"
			(fromText "\xA1\xA2.d")
		, test_CreateTree "iso8859"
			(decode "\xA1\xA2\xA3.d")
		]
	, test_ListDirectory
	, suite "removeFile"
		[ test_RemoveFile "ascii"
			(decode "test.txt")
		, test_RemoveFile "utf8"
			(fromText "\xA1\xA2.txt")
		, test_RemoveFile "iso8859"
			(decode "\xA1\xA2\xA3.txt")
		]
	, suite "removeDirectory"
		[ test_RemoveDirectory "ascii"
			(decode "test.d")
		, test_RemoveDirectory "utf8"
			(fromText "\xA1\xA2.d")
		, test_RemoveDirectory "iso8859"
			(decode "\xA1\xA2\xA3.d")
		]
	, suite "removeTree"
		[ test_RemoveTree "ascii"
			(decode "test.d")
		, test_RemoveTree "utf8"
			(fromText "\xA1\xA2.d")
		, test_RemoveTree "iso8859"
			(decode "\xA1\xA2\xA3.d")
		]
	, suite "getWorkingDirectory"
		[ test_GetWorkingDirectory "ascii"
			(decode "test.d")
		, test_GetWorkingDirectory "utf8"
			(fromText "\xA1\xA2.d")
		, test_GetWorkingDirectory "iso8859"
			(decode "\xA1\xA2\xA3.d")
		]
	, suite "setWorkingDirectory"
		[ test_SetWorkingDirectory "ascii"
			(decode "test.d")
		, test_SetWorkingDirectory "utf8"
			(fromText "\xA1\xA2.d")
		, test_SetWorkingDirectory "iso8859"
			(decode "\xA1\xA2\xA3.d")
		]
	, todo "getHomeDirectory"
	, todo "getDesktopDirectory"
	, todo "getDocumentsDirectory"
	, todo "getAppDataDirectory"
	, todo "getAppCacheDirectory"
	, todo "getAppConfigDirectory"
	, todo "copyFile"
	, suite "getModified"
		[ test_GetModified "ascii"
			(decode "test.txt")
		, test_GetModified "utf8"
			(fromText "\xA1\xA2.txt")
		, test_GetModified "iso8859"
			(decode "\xA1\xA2\xA3.txt")
		]
	, suite "getSize"
		[ test_GetSize "ascii"
			(decode "test.txt")
		, test_GetSize "utf8"
			(fromText "\xA1\xA2.txt")
		, test_GetSize "iso8859"
			(decode "\xA1\xA2\xA3.txt")
		]
	, todo "openFile"
	, todo "withFile"
	, todo "readFile"
	, todo "writeFile"
	, todo "appendFile"
	, todo "openTextFile"
	, todo "withTextFile"
	, todo "readTextFile"
	, todo "writeTextFile"
	, todo "appendTextFile"
	]

test_IsFile :: Text -> FilePath -> Suite
test_IsFile test_name file_name = assertionsWithTemp test_name $ \tmp -> do
	let path = tmp </> file_name
	
	before <- liftIO $ Filesystem.isFile path
	$expect (not before)
	
	touch_ffi path "contents\n"
	
	after <- liftIO $ Filesystem.isFile path
	$expect after

test_IsDirectory :: Text -> FilePath -> Suite
test_IsDirectory test_name dir_name = assertionsWithTemp test_name $ \tmp -> do
	let path = tmp </> dir_name
	
	before <- liftIO $ Filesystem.isDirectory path
	$expect (not before)
	
	mkdir_ffi path
	
	after <- liftIO $ Filesystem.isDirectory path
	$expect after

test_Rename :: Text -> FilePath -> FilePath -> Suite
test_Rename test_name old_name new_name = assertionsWithTemp test_name $ \tmp -> do
	let old_path = tmp </> old_name
	let new_path = tmp </> new_name
	
	touch_ffi old_path ""
	
	old_before <- liftIO $ Filesystem.isFile old_path
	new_before <- liftIO $ Filesystem.isFile new_path
	$expect old_before
	$expect (not new_before)
	
	liftIO $ Filesystem.rename old_path new_path
	
	old_after <- liftIO $ Filesystem.isFile old_path
	new_after <- liftIO $ Filesystem.isFile new_path
	$expect (not old_after)
	$expect new_after

test_CanonicalizePath :: Text -> FilePath -> FilePath -> Suite
test_CanonicalizePath test_name src_name dst_name = assertionsWithTemp test_name $ \tmp -> do
	let src_path = tmp </> src_name
	let subdir = tmp </> "subdir"
	
	-- canonicalize the directory first, to avoid false negatives if
	-- it gets placed in a symlinked location.
	mkdir_ffi subdir
	canon_subdir <- liftIO (Filesystem.canonicalizePath subdir)
	
	let dst_path = canon_subdir </> dst_name
	
	touch_ffi dst_path ""
	symlink_ffi dst_path src_path
	
	canonicalized <- liftIO $ Filesystem.canonicalizePath src_path
	$expect $ equal canonicalized dst_path

test_CreateDirectory :: Text -> FilePath -> Suite
test_CreateDirectory test_name dir_name = assertionsWithTemp test_name $ \tmp -> do
	let dir_path = tmp </> dir_name
	
	exists_before <- liftIO $ Filesystem.isDirectory dir_path
	$assert (not exists_before)
	
	liftIO $ Filesystem.createDirectory False dir_path
	exists_after <- liftIO $ Filesystem.isDirectory dir_path
	
	$expect exists_after

test_CreateDirectory_FailExists :: Suite
test_CreateDirectory_FailExists = assertionsWithTemp "fail-if-exists" $ \tmp -> do
	let dir_path = tmp </> "subdir"
	mkdir_ffi dir_path
	
	$expect $ throwsEq
		(mkAlreadyExists "createDirectory" dir_path)
		(Filesystem.createDirectory False dir_path)

test_CreateDirectory_SucceedExists :: Suite
test_CreateDirectory_SucceedExists = assertionsWithTemp "succeed-if-exists" $ \tmp -> do
	let dir_path = tmp </> "subdir"
	mkdir_ffi dir_path
	
	liftIO $ Filesystem.createDirectory True dir_path

test_CreateDirectory_FailFileExists :: Suite
test_CreateDirectory_FailFileExists = assertionsWithTemp "fail-if-file-exists" $ \tmp -> do
	let dir_path = tmp </> "subdir"
	touch_ffi dir_path ""
	
	$expect $ throwsEq
		(mkAlreadyExists "createDirectory" dir_path)
		(Filesystem.createDirectory False dir_path)
	$expect $ throwsEq
		(mkAlreadyExists "createDirectory" dir_path)
		(Filesystem.createDirectory True dir_path)

mkAlreadyExists :: String -> FilePath -> GHC.IOError
mkAlreadyExists loc path = GHC.IOError Nothing GHC.AlreadyExists loc "File exists"
#if MIN_VERSION_base(4,2,0)
	(Just (errnoCInt eEXIST))
#endif
	(Just (CurrentOS.encodeString path))

test_CreateTree :: Text -> FilePath -> Suite
test_CreateTree test_name dir_name = assertionsWithTemp test_name $ \tmp -> do
	let dir_path = tmp </> dir_name
	let subdir = dir_path </> "subdir"
	
	dir_exists_before <- liftIO $ Filesystem.isDirectory dir_path
	subdir_exists_before <- liftIO $ Filesystem.isDirectory subdir
	$assert (not dir_exists_before)
	$assert (not subdir_exists_before)
	
	liftIO $ Filesystem.createTree subdir
	dir_exists_after <- liftIO $ Filesystem.isDirectory dir_path
	subdir_exists_after <- liftIO $ Filesystem.isDirectory subdir
	
	$expect dir_exists_after
	$expect subdir_exists_after

test_ListDirectory :: Suite
test_ListDirectory = assertionsWithTemp "listDirectory" $ \tmp -> do
	let paths =
		[ tmp </> decode "test.txt"
		, tmp </> fromText "\xA1\xA2.txt"
		, tmp </> decode "\xA1\xA2\xA3.txt"
		]
	forM_ paths (\path -> touch_ffi path "")
	
	names <- liftIO $ Filesystem.listDirectory tmp
	$expect $ sameItems paths names

test_RemoveFile :: Text -> FilePath -> Suite
test_RemoveFile test_name file_name = assertionsWithTemp test_name $ \tmp -> do
	let file_path = tmp </> file_name
	
	touch_ffi file_path "contents\n"
	
	before <- liftIO $ Filesystem.isFile file_path
	$assert before
	
	liftIO $ Filesystem.removeFile file_path
	
	after <- liftIO $ Filesystem.isFile file_path
	$expect (not after)

test_RemoveDirectory :: Text -> FilePath -> Suite
test_RemoveDirectory test_name dir_name = assertionsWithTemp test_name $ \tmp -> do
	let dir_path = tmp </> dir_name
	
	mkdir_ffi dir_path
	
	before <- liftIO $ Filesystem.isDirectory dir_path
	$assert before
	
	liftIO $ Filesystem.removeDirectory dir_path
	
	after <- liftIO $ Filesystem.isDirectory dir_path
	$expect (not after)

test_RemoveTree :: Text -> FilePath -> Suite
test_RemoveTree test_name dir_name = assertionsWithTemp test_name $ \tmp -> do
	let dir_path = tmp </> dir_name
	let subdir = dir_path </> "subdir"
	
	mkdir_ffi dir_path
	mkdir_ffi subdir
	
	dir_before <- liftIO $ Filesystem.isDirectory dir_path
	subdir_before <- liftIO $ Filesystem.isDirectory subdir
	$assert dir_before
	$assert subdir_before
	
	liftIO $ Filesystem.removeTree dir_path
	
	dir_after <- liftIO $ Filesystem.isDirectory dir_path
	subdir_after <- liftIO $ Filesystem.isDirectory subdir
	$expect (not dir_after)
	$expect (not subdir_after)

test_GetWorkingDirectory :: Text -> FilePath -> Suite
test_GetWorkingDirectory test_name dir_name = assertionsWithTemp test_name $ \tmp -> do
	let dir_path = tmp </> dir_name
	
	mkdir_ffi dir_path
	chdir_ffi dir_path
	
	cwd <- liftIO $ Filesystem.getWorkingDirectory
	$expect (equal cwd dir_path)

test_SetWorkingDirectory :: Text -> FilePath -> Suite
test_SetWorkingDirectory test_name dir_name = assertionsWithTemp test_name $ \tmp -> do
	let dir_path = tmp </> dir_name
	
	mkdir_ffi dir_path
	liftIO $ Filesystem.setWorkingDirectory dir_path
	
	cwd <- getcwd_ffi
	$expect (equal cwd dir_path)

test_GetModified :: Text -> FilePath -> Suite
test_GetModified test_name file_name = assertionsWithTemp test_name $ \tmp -> do
	let file_path = tmp </> file_name
	
	touch_ffi file_path ""
	now <- liftIO getCurrentTime
	
	mtime <- liftIO $ Filesystem.getModified file_path
	$expect (equalWithin (diffUTCTime mtime now) 0 2)

test_GetSize :: Text -> FilePath -> Suite
test_GetSize test_name file_name = assertionsWithTemp test_name $ \tmp -> do
	let file_path = tmp </> file_name
	let contents = "contents\n"
	
	touch_ffi file_path contents
	
	size <- liftIO $ Filesystem.getSize file_path
	$expect (equal size (toInteger (Data.ByteString.length contents)))

withPathCString :: FilePath -> (CString -> IO a) -> IO a
withPathCString p = Data.ByteString.useAsCString (encode p)

decode :: ByteString -> FilePath
decode = Rules.decode Rules.posix

encode :: FilePath -> ByteString
encode = Rules.encode Rules.posix

fromText :: Text -> FilePath
fromText = Rules.fromText Rules.posix

-- | Create a file using the raw POSIX API, via FFI
touch_ffi :: FilePath -> Data.ByteString.ByteString -> Assertions ()
touch_ffi path contents = do
	fp <- liftIO $ withPathCString path $ \path_cstr ->
		Foreign.C.withCString "wb" $ \mode_cstr ->
		c_fopen path_cstr mode_cstr
	
	$assert (fp /= nullPtr)
	
	_ <- liftIO $ Data.ByteString.useAsCStringLen contents $ \(buf, len) ->
		c_fwrite buf 1 (fromIntegral len) fp
	
	_ <- liftIO $ c_fclose fp
	return ()

-- | Create a directory using the raw POSIX API, via FFI
mkdir_ffi :: FilePath -> Assertions ()
mkdir_ffi path = do
	ret <- liftIO $ withPathCString path $ \path_cstr ->
		c_mkdir path_cstr 0o700
	
	$assert (ret == 0)

-- | Create a symlink using the raw POSIX API, via FFI
symlink_ffi :: FilePath -> FilePath -> Assertions ()
symlink_ffi dst src  = do
	ret <- liftIO $
		withPathCString dst $ \dst_p ->
		withPathCString src $ \src_p ->
		c_symlink dst_p src_p
	
	$assert (ret == 0)

getcwd_ffi :: Assertions FilePath
getcwd_ffi = do
	buf <- liftIO $ c_getcwd nullPtr 0
	$assert (buf /= nullPtr)
	bytes <- liftIO $ Data.ByteString.packCString buf
	liftIO $ c_free buf
	return (decode bytes)

chdir_ffi :: FilePath -> Assertions ()
chdir_ffi path = do
	ret <- liftIO $
		withPathCString path $ \path_p ->
		c_chdir path_p
	$assert (ret == 0)

errnoCInt :: Errno -> CInt
errnoCInt (Errno x) = x

foreign import ccall unsafe "fopen"
	c_fopen :: CString -> CString -> IO (Ptr ())

foreign import ccall unsafe "fclose"
	c_fclose :: Ptr () -> IO CInt

foreign import ccall unsafe "fwrite"
	c_fwrite :: CString -> CSize -> CSize -> Ptr () -> IO CSize

foreign import ccall unsafe "mkdir"
	c_mkdir :: CString -> CInt -> IO CInt

foreign import ccall unsafe "symlink"
	c_symlink :: CString -> CString -> IO CInt

foreign import ccall unsafe "getcwd"
	c_getcwd :: CString -> CSize -> IO CString

foreign import ccall unsafe "chdir"
	c_chdir :: CString -> IO CInt

foreign import ccall unsafe "free"
	c_free :: Ptr a -> IO ()