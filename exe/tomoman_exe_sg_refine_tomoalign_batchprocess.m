% Tomoman is a set of wrapper scripts for preprocessing to tomogram data
% collected by SerialEM. 

% WW,SK,PSE

clear all;
close all;
clc;

%% Inputs

% Root dir
p.root_dir = '/fs/pool/pool-plitzko/Sagar/Projects/multishot/insitu/ecoli_ribosomes/threeshot/tomo/';    % Tomolist, reconstruction list, and bash scripts go here.
p.subtomo_dir = '/fs/pool/pool-plitzko/Sagar/Projects/multishot/insitu/ecoli_ribosomes/threeshot/subtomo/bin2_8k_tiltctf/';

% Tomolist
p.tomolist_name = 'tomolist_tiltctf.mat';     % Relative to rood_dir

% Parallelization on MPIB clusters
p.n_comp = 2;     % Number of computers/nodes for distributing tomograms should be mod of tomogram number!!!!
p.n_cores = 1;   % Number of cores per computer (20 for local, 40 for p.hpcl67, 1 for p.hpcl8)!!!!
p.queue = 'p.hpcl8'; % Queue: "local" or "p.hpcl67" or "p.hpcl8"!

% Outputs
script_name = 'sg_refine_tomoalign';    % Root name of output scripts. One is written for each computer.

% sg_refine options (REQUIRED)
p.digits = 3;
p.iteration = 1;             
p.refine_binning = 2;
p.motl_name = 'allmotl_3.star'; 
p.wedgelist_name = 'wedgelist_tiltctf.star'; 
p.stacklist_name = 'stacklist.star';

% IMOD parameters
p.stack='df';                  % Which stacks to process: 'r' = raw, 'w' = raw/whitened, 'df' = dose-filtered, 'dfw' = dosefiltered/whitened
p.xtilt = 'default';           % Xtilt to consider for ctf correction. 'default' = use from tilt.com, 'tomopitch' = use from tomopitch.log, 'motl' =  calculate from motl. not supported!
p.gpustring = '0';              % GPU string for IMOD UseGPU


% Parameters for Tomoalign (Please read the manual! )
p.tomoalign = 1;                % whether to run tiltalign before 
p.tomoalign_t = 'thick'; % 'thin' or 'thick'.
% p.tomoalign_motion = '3'; % '3' for 3d motion and '2' for 2d motion

% % Parameters for Tiltalign (Parameters you would want to change!) 
% % see TiltAlign Manpage for information on option
% p.ta_ImageSizeXandY = [1024,1024]; % Tilt stack image size used for refine
% p.ta_ImagePixelSizeXandY = 3.7188; % pixel size for the binning used for Refine
% p.ta_SurfacesToAnalyze = 2;
% % local alignment parameters
% p.ta_LocalAlignments = 1; % 1 = to perform local alignments, 0 = No local alignments
% p.ta_NumberOfLocalPatchesXandY = [6,6];
% p.ta_MinSizeOrOverlapXandY = 0.33;
% p.ta_MinFidsTotalAndEachSurface = [6,3];

% CTF parameters
p.correction_type = '2dctf';  % Options are 'none' or '2dctf' or '3dctf'. Caution!! '3dctf' works only when the motl and subtomo directory is  is provided!
% p.defocus_step = 15;              % Defocus step along tomogram thickness in nm
p.famp = 0.07;    % Amplitude contrast
p.cs = 2.7;       % Spherical abberation (mm)
p.evk = 300;      % Voltage


% Aligned stack size
p.ali_dim = [];
% Erase gold
p.goldradius = [84];      % Leave blank '[]' to skip.
% Taper
p.taper_pixels = 100;   % Leave blank '[]' to skip.
% Bin aligned stack
p.ali_stack_bin = [2];    % set to 1 for no binning.
% Bin tomogram
p.justbin = 0 ;       % 1 = just run the binning operation. 0 = otherwise.
p.tomo_bin = [];   % Multiple numbers for serial binning; i.e. [2,2] produces relatively binned tomograms.

% Fake SIRT iterations
p.fakesirtiter = [];  % fake SIRT iterations for better contrast!

% Tomogram directories
p.main_dir = [p.root_dir 'bin2_sg_refine_tomoalign/'];  % Destination of first tomogram (MAKE SURE IT"S THE RIGHT BINNING)
p.bin_dir = {};   % Destination of binned tomograms. For multiple binnings, supply as cell array.

% Subtomogram directory
p.subtomo_targetdir = ''; % absolute path to the target subtomo directory. Where would you like the refined subvolumes? 
% Pretilt option
p.pretilt = 0; % whether or not to apply pretilt (tiltcom parameter OFFSET) to tilt angles in .tlt file. 

% Reconstruction list  you want to process only a subset of tomograms from
% the motl (Optional: leave blanck to process all)
recons_list = '';    

% % Parameters for Tiltalign (Parameters you would NOT want to change!) 
% % see TiltAlign Manpage for information on option
% 
% % Global options
% p.ta_RotOption = 0;
% p.ta_RotDefaultGrouping = 3;
% p.ta_TiltOption = 5;
% p.ta_TiltDefaultGrouping = 3;
% p.ta_MagOption = 0;
% p.ta_MagDefaultGrouping = 3;
% p.ta_XStretchOption = 0;
% p.ta_SkewOption = 0;
% p.ta_BeamTiltOption = 0;
% p.ta_XTiltOption = 0;
% p.ta_ResidualReportCriterion = 0.001;
% p.ta_KFactorScaling = 0.5;
% 
% %Local options
% p.ta_LocalRotOption = 1;
% p.ta_LocalRotDefaultGrouping = 3;
% p.ta_LocalTiltOption = 0;
% p.ta_LocalTiltDefaultGrouping = 1;
% p.ta_LocalMagOption = 0;
% p.ta_LocalMagDefaultGrouping = 1;
% p.ta_LocalOutputOptions = '1,0,1';

%% Set some executable paths

% Fourier crop stack executable
p.fcrop_stack = '/fs/pool/pool-plitzko/Sagar/software/sagar/tomoman/10-2020/github/fcrop_stack/fourier_crop_stack.sh';

% Fourier crop volume executable
p.fcrop_vol = 'Fourier3D';
p.fcrop_vol_memlimit = 40000;


%% Check check

% Force p.bin_dir into cell array
if ~iscell(p.bin_dir)
    temp_bin_dir = p.bin_dir;
    p.bin_dir = cell(1,1);
    p.bin_dir{1} = temp_bin_dir;
end

% Check tomogram directories
n_binning = numel(p.tomo_bin);
if n_binning ~= numel(p.bin_dir)
    error('ACHTUNG!!! Number of bin_dir does not match number of tomo_bin!!!');
end



%% Initialize

% Read tomolist
if exist([p.root_dir,'/',p.tomolist_name],'file')
    disp('TOMOMAN: Old tomolist found... Loading tomolist!!!');
    load([p.root_dir,'/',p.tomolist_name]);
else
    error('TOMOMAN: No tomolist found!!!');
end

% read motl and wedgelist
if exist([p.subtomo_dir,'/lists/', p.motl_name],'file')
    motl = sg_motl_read([p.subtomo_dir,'/lists/', p.motl_name]);
else
    error('Motl not found!!!');
end

if exist([p.subtomo_dir,'/lists/', p.wedgelist_name],'file')
    wedgelist = sg_wedgelist_read([p.subtomo_dir,'/lists/', p.wedgelist_name]);
else
    error('Wedgelist not found!!!');
end

if exist([p.subtomo_dir,'/lists/', p.stacklist_name],'file')
    stacklist = sg_stacklist_read([p.subtomo_dir,'/lists/', p.stacklist_name]);
else
    error('stacklist not found!!!');
end

% Read reconstruction list

if ~isempty(recons_list)
    rlist = dlmread([p.root_dir,'/',recons_list]);    
else 
    rlist = unique([motl.tomo_num]);    
end
n_tomos = numel(rlist);

% Get indices of tomograms to reconstruct
[~,r_idx] = intersect([tomolist.tomo_num],rlist);

% Check for skips
skips = [tomolist(r_idx).skip];
if any(skips)
    skip_list = rlist(skips);
    for i = numel(skip_list)
        warning(['ACHTUNG!!! Tomogram ',num2str(skip_list(i)),' was set to skip!!!']);
    end
    
    % Update lists
    rlist = rlist(~skips);
    r_idx = r_idx(~skips);
    n_tomos = numel(rlist);
    
end

% Check tomogram directories
if ~exist(p.main_dir,'dir')
    mkdir(p.main_dir);
end
for i = 1:n_binning
    if ~exist(p.bin_dir{i},'dir')
        mkdir(p.bin_dir{i});
    end
end




% Loop through and generate scripts per tomogram
for i  = 1:n_tomos
    
    % Parse tomolist
    t = tomolist(r_idx(i));
    
    % Check IMOD folder
    if p.tomoalign
        if exist([t.stack_dir,'/sg_refine_tomoalign/'],'dir')
            system(['rm -rf ',t.stack_dir,'/sg_refine_tomoalign/']);
        end
        mkdir([t.stack_dir,'/sg_refine_tomoalign/']);   
    end
    
    % Read in tilt.com
    tiltcom = [t.stack_dir,'tilt.com'];
    
    % calculate unbinned zshift
    motl_ndx = [motl.tomo_num] == t.tomo_num;
    part_mean_z = mean([motl(motl_ndx).orig_z]);
    w_idx = [wedgelist.tomo_num] == t.tomo_num;
    tomo_z_center = (floor(((wedgelist(w_idx).tomo_z)/p.refine_binning)/2) + 1);
    zshift = (tomo_z_center - part_mean_z).*p.refine_binning;
    s_idx = [stacklist.tomo_num] == t.tomo_num;
    stack = stacklist(s_idx);

    
    if exist(tiltcom, 'file')
        tiltcom = tomoman_imod_parse_tiltcom([t.stack_dir,'tilt.com']);
              
        % Run tiltalign 
        if p.tomoalign
            tomoman_sg_refine_tomoalign(t,p,stack);
        end
        
        % Generate parallel stack-processing scripts
        tomoman_sg_refine_tomoalign_generate_imodtomorec_scripts(t,p,tiltcom);
        
        % Generate run script for tomogram
        tomoman_sg_refine_tomoalign_generate_tomogram_runscript(t,p);
    else
        warning('tilt.com not found! Skipping stack')
    end
end

% Generate batch scripts
tomoman_sg_refine_tomoalign_generate_batch_scripts(tomolist(r_idx),p,p.root_dir,script_name);