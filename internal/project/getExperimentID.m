function ID = getExperimentID(project, experimentName)
    ID = [];
    for it = 1:size(project.experiments,2)
        if(strcmp(project.experiments{it}, experimentName))
            ID = it;
            return;
        end
    end
end