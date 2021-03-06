-----------------------------------------------------------------------------
--  $Id: DriverPhases.hs,v 1.38 2005/05/17 11:01:59 simonmar Exp $
--
-- GHC Driver
--
-- (c) The University of Glasgow 2002
--
-----------------------------------------------------------------------------

module DriverPhases (
   HscSource(..), isHsBoot, hscSourceString,
   Phase(..),
   happensBefore, eqPhase, anyHsc, isStopLn,
   startPhase,          -- :: String -> Phase
   phaseInputExt,       -- :: Phase -> String

   isHaskellishSuffix,
   isHaskellSrcSuffix,
   isObjectSuffix,
   isCishSuffix,
   isExtCoreSuffix,
   isDynLibSuffix,
   isHaskellUserSrcSuffix,
   isSourceSuffix,

   isHaskellishFilename,
   isHaskellSrcFilename,
   isObjectFilename,
   isCishFilename,
   isExtCoreFilename,
   isDynLibFilename,
   isHaskellUserSrcFilename,
   isSourceFilename         -- :: FilePath -> Bool
 ) where

#include "HsVersions.h"

import Outputable
import System.FilePath

-----------------------------------------------------------------------------
-- Phases

{-
   Phase of the           | Suffix saying | Flag saying   | (suffix of)
   compilation system     | ``start here''| ``stop after''| output file

   literate pre-processor | .lhs          | -             | -
   C pre-processor (opt.) | -             | -E            | -
   Haskell compiler       | .hs           | -C, -S        | .hc, .s
   C compiler (opt.)      | .hc or .c     | -S            | .s
   assembler              | .s  or .S     | -c            | .o
   linker                 | other         | -             | a.out
-}

data HscSource
   = HsSrcFile | HsBootFile | ExtCoreFile
     deriving( Eq, Ord, Show )
        -- Ord needed for the finite maps we build in CompManager


hscSourceString :: HscSource -> String
hscSourceString HsSrcFile   = ""
hscSourceString HsBootFile  = "[boot]"
hscSourceString ExtCoreFile = "[ext core]"

isHsBoot :: HscSource -> Bool
isHsBoot HsBootFile = True
isHsBoot _          = False

data Phase
        = Unlit HscSource
        | Cpp   HscSource
        | HsPp  HscSource
        | Hsc   HscSource
        | Ccpp
        | Cc
        | Cobjc
        | Cobjcpp
        | HCc           -- Haskellised C (as opposed to vanilla C) compilation
        | SplitMangle   -- after mangler if splitting
        | SplitAs
        | As
        | LlvmOpt       -- Run LLVM opt tool over llvm assembly
        | LlvmLlc       -- LLVM bitcode to native assembly
        | LlvmMangle    -- Fix up TNTC by processing assembly produced by LLVM
        | CmmCpp        -- pre-process Cmm source
        | Cmm           -- parse & compile Cmm code
        | MergeStub     -- merge in the stub object file

        -- The final phase is a pseudo-phase that tells the pipeline to stop.
        -- There is no runPhase case for it.
        | StopLn        -- Stop, but linking will follow, so generate .o file
  deriving (Eq, Show)

instance Outputable Phase where
    ppr p = text (show p)

anyHsc :: Phase
anyHsc = Hsc (panic "anyHsc")

isStopLn :: Phase -> Bool
isStopLn StopLn = True
isStopLn _      = False

eqPhase :: Phase -> Phase -> Bool
-- Equality of constructors, ignoring the HscSource field
-- NB: the HscSource field can be 'bot'; see anyHsc above
eqPhase (Unlit _)   (Unlit _)   = True
eqPhase (Cpp   _)   (Cpp   _)   = True
eqPhase (HsPp  _)   (HsPp  _)   = True
eqPhase (Hsc   _)   (Hsc   _)   = True
eqPhase Ccpp        Ccpp        = True
eqPhase Cc          Cc          = True
eqPhase Cobjc       Cobjc       = True
eqPhase Cobjcpp     Cobjcpp     = True
eqPhase HCc         HCc         = True
eqPhase SplitMangle SplitMangle = True
eqPhase SplitAs     SplitAs     = True
eqPhase As          As          = True
eqPhase LlvmOpt	    LlvmOpt 	= True
eqPhase LlvmLlc	    LlvmLlc 	= True
eqPhase LlvmMangle  LlvmMangle 	= True
eqPhase CmmCpp      CmmCpp      = True
eqPhase Cmm         Cmm         = True
eqPhase MergeStub   MergeStub   = True
eqPhase StopLn      StopLn      = True
eqPhase _           _           = False

-- Partial ordering on phases: we want to know which phases will occur before
-- which others.  This is used for sanity checking, to ensure that the
-- pipeline will stop at some point (see DriverPipeline.runPipeline).
happensBefore :: Phase -> Phase -> Bool
StopLn `happensBefore` _ = False
x      `happensBefore` y = after_x `eqPhase` y || after_x `happensBefore` y
        where
          after_x = nextPhase x

nextPhase :: Phase -> Phase
-- A conservative approximation to the next phase, used in happensBefore
nextPhase (Unlit sf)    = Cpp  sf
nextPhase (Cpp   sf)    = HsPp sf
nextPhase (HsPp  sf)    = Hsc  sf
nextPhase (Hsc   _)     = HCc
nextPhase SplitMangle   = As
nextPhase As            = SplitAs
nextPhase LlvmOpt       = LlvmLlc
nextPhase LlvmLlc       = LlvmMangle
nextPhase LlvmMangle    = As
nextPhase SplitAs       = MergeStub
nextPhase Ccpp          = As
nextPhase Cc            = As
nextPhase Cobjc         = As
nextPhase Cobjcpp       = As
nextPhase CmmCpp        = Cmm
nextPhase Cmm           = HCc
nextPhase HCc           = As
nextPhase MergeStub     = StopLn
nextPhase StopLn        = panic "nextPhase: nothing after StopLn"

-- the first compilation phase for a given file is determined
-- by its suffix.
startPhase :: String -> Phase
startPhase "lhs"      = Unlit HsSrcFile
startPhase "lhs-boot" = Unlit HsBootFile
startPhase "hs"       = Cpp   HsSrcFile
startPhase "hs-boot"  = Cpp   HsBootFile
startPhase "hscpp"    = HsPp  HsSrcFile
startPhase "hspp"     = Hsc   HsSrcFile
startPhase "hcr"      = Hsc   ExtCoreFile
startPhase "hc"       = HCc
startPhase "c"        = Cc
startPhase "cpp"      = Ccpp
startPhase "C"        = Cc
startPhase "m"        = Cobjc
startPhase "M"        = Cobjcpp
startPhase "mm"       = Cobjcpp
startPhase "cc"       = Ccpp
startPhase "cxx"      = Ccpp
startPhase "split_s"  = SplitMangle
startPhase "s"        = As
startPhase "S"        = As
startPhase "ll"       = LlvmOpt
startPhase "bc"       = LlvmLlc
startPhase "lm_s"     = LlvmMangle
startPhase "o"        = StopLn
startPhase "cmm"      = CmmCpp
startPhase "cmmcpp"   = Cmm
startPhase _          = StopLn     -- all unknown file types

-- This is used to determine the extension for the output from the
-- current phase (if it generates a new file).  The extension depends
-- on the next phase in the pipeline.
phaseInputExt :: Phase -> String
phaseInputExt (Unlit HsSrcFile)   = "lhs"
phaseInputExt (Unlit HsBootFile)  = "lhs-boot"
phaseInputExt (Unlit ExtCoreFile) = "lhcr"
phaseInputExt (Cpp   _)           = "lpp"       -- intermediate only
phaseInputExt (HsPp  _)           = "hscpp"     -- intermediate only
phaseInputExt (Hsc   _)           = "hspp"      -- intermediate only
        -- NB: as things stand, phaseInputExt (Hsc x) must not evaluate x
        --     because runPipeline uses the StopBefore phase to pick the
        --     output filename.  That could be fixed, but watch out.
phaseInputExt HCc                 = "hc"
phaseInputExt Ccpp                = "cpp"
phaseInputExt Cobjc               = "m"
phaseInputExt Cobjcpp             = "mm"
phaseInputExt Cc                  = "c"
phaseInputExt SplitMangle         = "split_s"   -- not really generated
phaseInputExt As                  = "s"
phaseInputExt LlvmOpt             = "ll"
phaseInputExt LlvmLlc             = "bc"
phaseInputExt LlvmMangle          = "lm_s"
phaseInputExt SplitAs             = "split_s"   -- not really generated
phaseInputExt CmmCpp              = "cmm"
phaseInputExt Cmm                 = "cmmcpp"
phaseInputExt MergeStub           = "o"
phaseInputExt StopLn              = "o"

haskellish_src_suffixes, haskellish_suffixes, cish_suffixes,
    extcoreish_suffixes, haskellish_user_src_suffixes
 :: [String]
haskellish_src_suffixes      = haskellish_user_src_suffixes ++
                               [ "hspp", "hscpp", "hcr", "cmm", "cmmcpp" ]
haskellish_suffixes          = haskellish_src_suffixes ++ ["hc", "raw_s"]
cish_suffixes                = [ "c", "cpp", "C", "cc", "cxx", "s", "S", "ll", "bc", "lm_s", "m", "M", "mm" ]
extcoreish_suffixes          = [ "hcr" ]
-- Will not be deleted as temp files:
haskellish_user_src_suffixes = [ "hs", "lhs", "hs-boot", "lhs-boot" ]

objish_suffixes :: [String]
-- Use the appropriate suffix for the system on which
-- the GHC-compiled code will run
#if mingw32_TARGET_OS || cygwin32_TARGET_OS
objish_suffixes     = [ "o", "O", "obj", "OBJ" ]
#else
objish_suffixes     = [ "o" ]
#endif

dynlib_suffixes :: [String]
#ifdef mingw32_TARGET_OS
dynlib_suffixes = ["dll", "DLL"]
#elif defined(darwin_TARGET_OS)
dynlib_suffixes = ["dylib"]
#else
dynlib_suffixes = ["so"]
#endif

isHaskellishSuffix, isHaskellSrcSuffix, isCishSuffix, isExtCoreSuffix,
    isObjectSuffix, isHaskellUserSrcSuffix, isDynLibSuffix
 :: String -> Bool
isHaskellishSuffix     s = s `elem` haskellish_suffixes
isHaskellSrcSuffix     s = s `elem` haskellish_src_suffixes
isCishSuffix           s = s `elem` cish_suffixes
isExtCoreSuffix        s = s `elem` extcoreish_suffixes
isObjectSuffix         s = s `elem` objish_suffixes
isHaskellUserSrcSuffix s = s `elem` haskellish_user_src_suffixes
isDynLibSuffix         s = s `elem` dynlib_suffixes

isSourceSuffix :: String -> Bool
isSourceSuffix suff  = isHaskellishSuffix suff || isCishSuffix suff

isHaskellishFilename, isHaskellSrcFilename, isCishFilename,
    isExtCoreFilename, isObjectFilename, isHaskellUserSrcFilename,
    isDynLibFilename, isSourceFilename
 :: FilePath -> Bool
-- takeExtension return .foo, so we drop 1 to get rid of the .
isHaskellishFilename     f = isHaskellishSuffix     (drop 1 $ takeExtension f)
isHaskellSrcFilename     f = isHaskellSrcSuffix     (drop 1 $ takeExtension f)
isCishFilename           f = isCishSuffix           (drop 1 $ takeExtension f)
isExtCoreFilename        f = isExtCoreSuffix        (drop 1 $ takeExtension f)
isObjectFilename         f = isObjectSuffix         (drop 1 $ takeExtension f)
isHaskellUserSrcFilename f = isHaskellUserSrcSuffix (drop 1 $ takeExtension f)
isDynLibFilename         f = isDynLibSuffix         (drop 1 $ takeExtension f)
isSourceFilename         f = isSourceSuffix         (drop 1 $ takeExtension f)


