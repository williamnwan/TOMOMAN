function tomoman_novactf_generate_tomogram_runscript(t,p,n_stacks,tiltcom)
%% will_novactf_generate_tomogram_runscript
% A function to generate a 'runscript' for running novaCTF on a tilt-stack.
% When run, the runscript first runs parallel processing of tilt-stacks via
% MPI; when the MPI job is completed, it finishes the tomogram by running
% novaCTF. The tomogram is then binned via Fourier cropping and the 
% intermediate files are deleted. 
%
% WW 01-2018

%% Initialize

% Parse tlt filename
[~,name,~] = fileparts(t.dose_filtered_stack_name);
tltname = [name,'.tlt'];

% Determine number of cores
if n_stacks < p.n_cores
    n_cores = n_stacks;
else
    n_cores = p.n_cores;
end

% THICKNESS string
if ~isempty(p.ali_stack_bin)    
    thick_str =  num2str(tiltcom.THICKNESS/p.ali_stack_bin);
else
    thick_str  =  num2str(tiltcom.THICKNESS);
end

% FULLIMAGE string
if ~isempty(p.ali_dim)  % If aligned stack has new dimensions
    % If aligned stack was binned 
    if ~isempty(p.ali_stack_bin)           
        bin_x = ceil(p.ali_dim(1)/(p.ali_stack_bin*2))*2;
        bin_y = ceil(p.ali_dim(2)/(p.ali_stack_bin*2))*2;
        fullimage_str = [num2str(bin_x),',',num2str(bin_y)];
    else
        fullimage_str = [num2str(p.ali_dim(1)),',',num2str(p.ali_dim(2))];
    end
else
    if  ~isempty(p.ali_stack_bin)
        bin_x = ceil(tiltcom.FULLIMAGE(1)/(p.ali_stack_bin*2))*2;
        bin_y = ceil(tiltcom.FULLIMAGE(2)/(p.ali_stack_bin*2))*2;
        fullimage_str = [num2str(bin_x),',',num2str(bin_y)];
    else
        fullimage_str = [num2str(tiltcom.FULLIMAGE(1)),',',num2str(tiltcom.FULLIMAGE(2))];
    end
end
    
% SHIFT string
if ~isempty(p.ali_stack_bin)    
    shift_str =  [num2str(tiltcom.SHIFT(1)/p.ali_stack_bin),',',num2str(tiltcom.SHIFT(2)/p.ali_stack_bin)];
else
    shift_str =  [num2str(tiltcom.SHIFT(1)),',',num2str(tiltcom.SHIFT(2))];
end
        
% PixelSize string
if ~isempty(p.ali_stack_bin)    
    pixelsize_str = num2str((t.pixelsize*p.ali_stack_bin)/10);
else
    pixelsize_str = num2str(t.pixelsize/(10));
end


%% Check for refined center

if isfield(p,'mean_z')
    tomo_idx = p.mean_z(1,:) == t.tomo_num; % Find tomogram index
    mean_z = round(p.mean_z(2,tomo_idx));   % Parse mean Z value
    cen_name = [t.stack_dir,'/novactf/refined_cen.txt'];
    dlmwrite(cen_name,mean_z);
    new_cen = ['DefocusShiftFile ',cen_name];
else
    new_cen = [];
end
    


%% Generate run script

% Open run script
rscript = fopen([t.stack_dir,'/novactf/run_novaCTF.sh'],'w');


% Write initial lines for submission on either local or hpcl700x (p.512g)
% 
% EDIT SK 27112019
switch p.queue
    case 'p.512g'
        error('Oops!! 404');
%         fprintf(rscript,['#! /usr/bin/env bash\n\n',...
%             '#$ -pe openmpi 40\n',...            % Number of cores
%             '#$ -l h_vmem=128G\n',...            % Memory limit
%             '#$ -l h_rt=604800\n',...              % Wall time
%             '#$ -q ',p.queue,'\n',...                       %  queue
%             '#$ -e ',t.stack_dir,'/novactf/error_novactf\n',...       % Error file
%             '#$ -o ',t.stack_dir,'/novactf/log_novactf\n',...         % Log file
%             '#$ -S /bin/bash\n',...                      % Submission environment
%             'source ~/.bashrc\n\n',]);                      % Get proper envionment; i.e. modules

    case 'p.192g'
        error('Oops!! 404');
%         fprintf(rscript,['#! /usr/bin/env bash\n\n',...
%             '#$ -pe openmpi 16\n',...            % Number of cores
%             '#$ -l h_vmem=128G\n',...            % Memory limit
%             '#$ -l h_rt=604800\n',...              % Wall time
%             '#$ -q ',p.queue,'\n',...                       %  queue
%             '#$ -e ',t.stack_dir,'/novactf/error_novactf\n',...       % Error file
%             '#$ -o ',t.stack_dir,'/novactf/log_novactf\n',...         % Log file
%             '#$ -S /bin/bash\n',...                      % Submission environment
%             'source ~/.bashrc\n\n',]);                      % Get proper envionment; i.e. modules        
    case 'local'
        fprintf(rscript,['#!/usr/bin/env bash \n\n','echo $HOSTNAME\n','set -e \n','set -o nounset \n\n']);
            
    case 'p.hpcl67'
        fprintf(rscript,['#!/bin/bash -l\n',...
            '# Standard output and error:\n',...
            '#SBATCH -e ' ,t.stack_dir,'/novactf/error_novactf\n',...
            '#SBATCH -o ' ,t.stack_dir,'/novactf/log_novactf\n',...
            '# Initial working directory:\n',...
            '#SBATCH -D ./\n',...
            '# Job Name:\n',...
            '#SBATCH -J NovaCTF\n',...
            '# Queue (Partition):\n',...
            '#SBATCH --partition=p.hpcl67 \n',...
            '# Number of nodes and MPI tasks per node:\n',...
            '#SBATCH --nodes=1\n',...
            '#SBATCH --ntasks=40\n',...
            '#SBATCH --ntasks-per-node=40\n',...
            '#SBATCH --cpus-per-task=1\n',...            %'#SBATCH --gres=gpu:2\n',...
            '#\n',...
            '#SBATCH --mail-type=none\n',...
            '#SBATCH --mem 510000\n',...
            '#\n',...
            '# Wall clock limit:\n',...
            '#SBATCH --time=168:00:00\n',...
            'echo "setting up environment"\n',...
            'module purge\n',...
            'module load intel/18.0.5\n',...
            'module load impi/2018.4\n',...
            '#load module for your application\n',...
            'module load NOVACTF\n',...
            'module load FOURIER3D\n',...
            'module load IMOD\n',...
            'export IMOD_PROCESSORS=40\n']);                      % Get proper envionment; i.e. modules
        
    otherwise
            error('only "local" or "p.hpcl67" are supported queques for p.queue!!!!')
        
    
end


% Run parallel scripts
fprintf(rscript,['# Process stacks in parallel','\n']);
fprintf(rscript,['mpiexec -np ',num2str(n_cores),' ',t.stack_dir,'novactf/scripts/mpi_stack_process.sh','\n\n']);

% Reconstruct with novaCTF
fprintf(rscript,['# Reconstruct tomogram with novaCTF','\n']);
fprintf(rscript,[p.novactf,' -Algorithm 3dctf ',...
                 '-InputProjections ',t.stack_dir,'novactf/stacks/aligned_stack.ali ',...
                 '-OutputFile ',p.main_dir,'/',num2str(t.tomo_num),'.rec ',...
                 '-TILTFILE ',t.stack_dir,tltname,' ',...
                 '-THICKNESS ',thick_str,' ',...
                 '-FULLIMAGE ',fullimage_str,' ',...
                 '-SHIFT ',shift_str,' ',...
                 '-PixelSize ',pixelsize_str,' ',...
                 '-DefocusStep ',num2str(p.defocus_step),' ',...
                 '-Use3DCTF 1 ',...
                 new_cen,...
                 '> ',t.stack_dir,'novactf/logs/3dctf_log.txt 2>&1','\n\n']);
             
% Rotate tomogram
fprintf(rscript,['# Rotate tomogram about X','\n']);
fprintf(rscript,['clip rotx ',p.main_dir,'/',num2str(t.tomo_num),'.rec ',p.main_dir,'/',num2str(t.tomo_num),'.rec','\n\n']);

% Remove temporary files
fprintf(rscript,['# Remove temporary files','\n']);
fprintf(rscript,['rm -f ',p.main_dir,'/',num2str(t.tomo_num),'.rec~','\n']);
fprintf(rscript,['rm -f ',t.stack_dir,'novactf/stacks/*','\n\n']);

% Bin tomogram
in_name = [p.main_dir,'/',num2str(t.tomo_num),'.rec'];  % Input tomogram name
for i = 1:numel(p.tomo_bin)
    
    % Ouptut tomogram name
    out_name = [p.bin_dir{i},'/',num2str(t.tomo_num),'.rec'];
    
    fprintf(rscript,['# Fourier crop tomogram by a factor of ',num2str(prod(p.tomo_bin(1:i))),'\n']);
    fprintf(rscript,[p.fcrop_vol,' ',...
                     '-InputFile ',in_name,' ',...
                     '-OutputFile ',out_name,' ',...
                     '-BinFactor ',num2str(p.tomo_bin(i)),' ',...
                     '-MemoryLimit ',num2str(p.fcrop_vol_memlimit),' ',...
                     '> ',t.stack_dir,'novactf/logs/binning_log.txt 2>&1','\n\n']);
    
    % Set for serial binning on next pass
    in_name = out_name;
end

% Close file and make executable
fclose(rscript);
system(['chmod +x ',t.stack_dir,'/novactf/run_novaCTF.sh']);

                 


